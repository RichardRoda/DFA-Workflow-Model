
use dfa;

drop procedure if exists dfa.processSubActions;
delimiter GO
create procedure dfa.processSubActions(spawnDfaWorkflowId BIGINT UNSIGNED, originalDfaStateId MEDIUMINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
	DECLARE SUB_WORKFLOW VARCHAR(128) default NULL;
	declare cursor_done, subState bit default false;
	declare nestedWorkflowTyp INT;
	declare nestedDfaWorkflowId BIGINT UNSIGNED;
	declare stateTyp INT;
	declare spawnDfaStateId MEDIUMINT UNSIGNED;
	declare state_typ_create cursor for select LKUP_WORKFLOW_STATE_TYP_CREATE.WORKFLOW_TYP, LKUP_WORKFLOW_STATE_TYP_CREATE.SUB_STATE 
		from LKUP_WORKFLOW_STATE_TYP_CREATE where LKUP_WORKFLOW_STATE_TYP_CREATE.STATE_TYP = stateTyp ORDER BY LKUP_WORKFLOW_STATE_TYP_CREATE.WORKFLOW_TYP;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET cursor_done = TRUE;

	IF EXISTS (select 1 from LKUP_WORKFLOW_STATE_TYP_CREATE JOIN DFA_WORKFLOW_STATE ON LKUP_WORKFLOW_STATE_TYP_CREATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP
		WHERE DFA_WORKFLOW_ID = spawnDfaWorkflowId AND DFA_STATE_ID <> originalDfaStateId AND IS_CURRENT = 1) THEN

      select concat('Started because ', LKUP_EVENT.EVENT_NM, ' on workflow ', LKUP_WORKFLOW_TYP.WORKFLOW_NM, ' entered state ', LKUP_STATE.STATE_NM), DFA_WORKFLOW_STATE.DFA_STATE_ID, DFA_WORKFLOW_STATE.STATE_TYP into SUB_WORKFLOW, spawnDfaStateId, stateTyp
      	from DFA_WORKFLOW_STATE 
      	JOIN LKUP_STATE ON LKUP_STATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP
      	JOIN LKUP_EVENT ON LKUP_EVENT.EVENT_TYP = DFA_WORKFLOW_STATE.EVENT_TYP
      	JOIN DFA_WORKFLOW ON DFA_WORKFLOW.DFA_WORKFLOW_ID = spawnDfaWorkflowId
      	JOIN LKUP_WORKFLOW_TYP ON LKUP_WORKFLOW_TYP.WORKFLOW_TYP = DFA_WORKFLOW.WORKFLOW_TYP
			WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = spawnDfaWorkflowId AND IS_CURRENT = 1;

		open state_typ_create;
	-- handle any sub-workflows.
    read_loop: LOOP
      FETCH state_typ_create into nestedWorkflowTyp, subState;
      IF cursor_done THEN
		  close state_typ_create;
        LEAVE read_loop;
      END IF;      
      CALL dfa.sp_do_startWorkflow(nestedWorkflowTyp, SUB_WORKFLOW, modBy, 0, refConstraintId, spawnDfaWorkflowId, spawnDfaStateId, subState, nestedDfaWorkflowId);
      END LOOP;
	END IF;	
END GO
delimiter ;

DROP PROCEDURE IF EXISTS dfa.sp_do_startWorkflow;
delimiter GO
CREATE PROCEDURE dfa.sp_do_startWorkflow(workflowTyp INT, commentTx MEDIUMTEXT, modBy VARCHAR(32), raiseError BIT, refConstraintId INT, spawnDfaWorkflowId BIGINT UNSIGNED, spawnDfaStateId MEDIUMINT UNSIGNED, subState BIT, OUT dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
	DECLARE ERROR_TX VARCHAR(128);
		
	IF EXISTS (select * from ref_dfa_constraint join LKUP_WORKFLOW_TYP ON 
		LKUP_WORKFLOW_TYP.CONSTRAINT_ID = ref_dfa_constraint.CONSTRAINT_ID
        where REF_ID = refConstraintId and ALLOW_UPDATE=1) THEN
		INSERT INTO DFA_WORKFLOW (WORKFLOW_TYP,COMMENT_TX,MOD_BY,SPAWN_DFA_WORKFLOW_ID,SPAWN_DFA_STATE_ID,SUB_STATE)
			VALUES (workflowTyp, commentTx, modBy,SPAWN_DFA_WORKFLOW_ID,SPAWN_DFA_STATE_ID,SUB_STATE);	
		SET dfaWorkflowId =  LAST_INSERT_ID();
        update DFA_WORKFLOW_STATE SET COMMENT_TX = 'Workflow started' where DFA_WORKFLOW_ID = dfaWorkflowId AND IS_CURRENT = 1;
		CALL dfa.processSubActions(dfaWorkflowId, 0);
    ELSE
		SET dfaWorkflowId = NULL;
        if (raiseError = 1) THEN
			SELECT CONCAT('Unable to start workflow of type ', workflowTyp, ' because the user lacks update permission on it')
				INTO ERROR_TX;
			SIGNAL SQLSTATE '45000' SET message_text=ERROR_TX;
        END IF;
    END IF;
END GO
delimiter ;



DROP PROCEDURE IF EXISTS dfa.sp_startWorkflow;
delimiter GO
CREATE PROCEDURE dfa.sp_startWorkflow(workflowTyp INT, commentTx MEDIUMTEXT, modBy VARCHAR(32), raiseError BIT, refConstraintId INT, OUT dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
	CALL dfa.sp_do_startWorkflow(workflowTyp, commentTx, modBy, raiseError, refConstraintId, NULL, NULL, FALSE, dfaWorkflowId);
END GO
delimiter ;

grant ALL on dfa.sp_startWorkflow to dfa_user;
flush PRIVILEGES;

/*
-- Unit test for dfa.sp_startWorkflow
use dfa;

INSERT INTO LKUP_STATE
	(STATE_TYP, STATE_NM, STATE_TX, MOD_BY)
	VALUES (1, 'First', 'First State', 'TEST');
INSERT INTO LKUP_STATE
	(STATE_TYP, STATE_NM, STATE_TX, MOD_BY)
	VALUES (2, 'Second', 'Second State', 'TEST');
	
INSERT INTO LKUP_EVENT_STATE_TRANS
	(STATE_TYP, EVENT_TYP, NEXT_STATE_TYP, MOD_BY)
	VALUES (1, 1, 2, 'TEST');
	
INSERT INTO LKUP_WORKFLOW_TYP
(WORKFLOW_TYP,WORKFLOW_NM,WORKFLOW_TX,START_STATE_TYP,START_EVENT_TYP,CONSTRAINT_ID,MOD_BY)
VALUES (1,'Test Workflow','Workflow Test',1,1,1,'Test');

-- Added this to make it possible to distinguish STATE_TYP with EVENT_TYP.
INSERT INTO LKUP_WORKFLOW_TYP
(WORKFLOW_TYP,WORKFLOW_NM,WORKFLOW_TX,START_STATE_TYP,START_EVENT_TYP,CONSTRAINT_ID,MOD_BY)
VALUES (2,'Test Workflow 2','Workflow Test 2',2,1,1,'Test');

-- Typically, run from here.
delete from session_dfa_constraint where CONSTRAINT_ID=1;
insert session_dfa_constraint (CONSTRAINT_ID, ALLOW_UPDATE, IS_RESPONSIBLE)
VALUES (1,1,0);

select concat(convert(current_timestamp(), char), ' Test') INTO @dfa_workflow_proc_unit_test_comment;
CALL dfa.sp_startWorkflow(1,@dfa_workflow_proc_unit_test_comment, 'test', 1, 0 ,@dfa_workflow_insert_ut_id);    
CALL dfa.sp_startWorkflow(2,@dfa_workflow_proc_unit_test_comment, 'test', 1, 0 ,@dfa_workflow_insert_ut_id_2);
    
delete from session_dfa_constraint where CONSTRAINT_ID=1;

CALL dfa.sp_startWorkflow(1,@dfa_workflow_proc_unit_test_comment, 'test', 0, 0 ,@dfa_workflow_insert_should_be_null_1);

insert session_dfa_constraint (CONSTRAINT_ID, ALLOW_UPDATE, IS_RESPONSIBLE)
VALUES (1,0,0);

CALL dfa.sp_startWorkflow(1,@dfa_workflow_proc_unit_test_comment, 'test', 0, 0 ,@dfa_workflow_insert_should_be_null_2);

select case when exists (select * from DFA_WORKFLOW WHERE DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id AND WORKFLOW_TYP = 1
	AND COMMENT_TX = @dfa_workflow_proc_unit_test_comment AND MOD_BY='test') 
	THEN 'PASS' ELSE 'FAIL 1' END AS RESULT
UNION select case when exists (select * from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id AND DFA_STATE_ID = 1 AND IS_CURRENT = 1 and IS_PASSIVE = 0 AND UNDO_STATE_ID IS NULL and PARENT_STATE_ID = 1 AND STATE_TYP=1 AND EVENT_TYP=1) 
	THEN 'PASS' ELSE 'FAIL 2' END AS RESULT
UNION select case when exists (select * from DFA_WORKFLOW WHERE DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id_2 AND WORKFLOW_TYP = 2
	AND COMMENT_TX = @dfa_workflow_proc_unit_test_comment AND MOD_BY='test') 
	THEN 'PASS' ELSE 'FAIL 1' END AS RESULT
UNION select case when exists (select * from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id_2 AND DFA_STATE_ID = 1 AND IS_CURRENT = 1 and IS_PASSIVE = 0 AND UNDO_STATE_ID IS NULL and PARENT_STATE_ID = 1 AND STATE_TYP=2 AND EVENT_TYP=1) 
	THEN 'PASS' ELSE 'FAIL 2' END AS RESULT
UNION select case when @dfa_workflow_insert_should_be_null_1 IS NULL THEN 'PASS' ELSE 'FAIL 5' END AS RESULT
UNION select case when @dfa_workflow_insert_should_be_null_2 IS NULL THEN 'PASS' ELSE 'FAIL 6' END AS RESULT;

-- This should FAIL with an ERROR.
CALL dfa.sp_startWorkflow(1,@dfa_workflow_proc_unit_test_comment, 'test', 1, 0 ,@dfa_workflow_insert_ut_id);
*/
