
DROP PROCEDURE IF EXISTS dfa.sp_startWorkflow;
delimiter GO
CREATE PROCEDURE dfa.sp_startWorkflow(workflowTyp INT, commentTx MEDIUMTEXT, modBy VARCHAR(32), raiseError BIT, refConstraintId INT, OUT dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
	DECLARE ERROR_TX VARCHAR(128);
	IF EXISTS (select * from ref_dfa_constraint join LKUP_WORKFLOW_TYP ON 
		LKUP_WORKFLOW_TYP.CONSTRAINT_ID = ref_dfa_constraint.CONSTRAINT_ID
        where REF_ID = refConstraintId and ALLOW_UPDATE=1) THEN
		INSERT INTO DFA_WORKFLOW (WORKFLOW_TYP,COMMENT_TX,MOD_BY)
			VALUES (workflowTyp, commentTx, modBy);	
		SET dfaWorkflowId =  LAST_INSERT_ID();
        update DFA_WORKFLOW_STATE SET COMMENT_TX = 'Workflow started' where DFA_WORKFLOW_ID = dfaWorkflowId AND IS_CURRENT = 1;
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

grant EXECUTE on dfa.sp_startWorkflow to dfa_user;

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
