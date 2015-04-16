
use dfa;

drop procedure if exists dfa.processSubActions;
delimiter GO
create procedure dfa.processSubActions(spawnDfaWorkflowId BIGINT UNSIGNED, originalDfaStateId MEDIUMINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
/*
This is an internal procedure that creates any subactions when a DFA enters a given state.  The current state of the DFA 
before any traisitions are applied to it is passed in.  This is to prevent spurious actions from being created
when an state is passive or no transition occurred because of constraints.
*/
	DECLARE SUB_WORKFLOW VARCHAR(128) default NULL;
	declare cursor_done, subState bit default false;
	declare nestedWorkflowTyp INT;
	declare nestedDfaWorkflowId BIGINT UNSIGNED;
	declare stateTyp INT;
	declare spawnDfaStateId MEDIUMINT UNSIGNED;
	declare state_typ_create cursor for select LKUP_WORKFLOW_STATE_TYP_CREATE.WORKFLOW_TYP, LKUP_WORKFLOW_STATE_TYP_CREATE.SUB_STATE 
		from LKUP_WORKFLOW_STATE_TYP_CREATE JOIN ref_dfa_constraint ON REF_ID = 1 AND ref_dfa_constraint.CONSTRAINT_ID = LKUP_WORKFLOW_STATE_TYP_CREATE.CONSTRAINT_ID
        where ref_dfa_constraint.ALLOW_UPDATE = 1 AND LKUP_WORKFLOW_STATE_TYP_CREATE.STATE_TYP = stateTyp ORDER BY LKUP_WORKFLOW_STATE_TYP_CREATE.WORKFLOW_TYP;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET cursor_done = TRUE;

	IF EXISTS (select 1 from LKUP_WORKFLOW_STATE_TYP_CREATE JOIN DFA_WORKFLOW_STATE ON LKUP_WORKFLOW_STATE_TYP_CREATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP
		JOIN ref_dfa_constraint ON REF_ID = 1 AND ref_dfa_constraint.CONSTRAINT_ID = LKUP_WORKFLOW_STATE_TYP_CREATE.CONSTRAINT_ID
		WHERE ref_dfa_constraint.ALLOW_UPDATE = 1 AND DFA_WORKFLOW_ID = spawnDfaWorkflowId AND DFA_STATE_ID <> originalDfaStateId AND IS_CURRENT = 1) THEN

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
      CALL dfa.sp_do_startWorkflow(nestedWorkflowTyp, SUB_WORKFLOW, modBy, 0, 1, spawnDfaWorkflowId, spawnDfaStateId, subState, nestedDfaWorkflowId);
      END LOOP;
	END IF;	
END GO
delimiter ;

DROP PROCEDURE IF EXISTS dfa.sp_do_startWorkflow;
delimiter GO
CREATE PROCEDURE dfa.sp_do_startWorkflow(workflowTyp INT, commentTx MEDIUMTEXT, modBy VARCHAR(32), raiseError BIT, refConstraintId INT, spawnDfaWorkflowId BIGINT UNSIGNED, spawnDfaStateId MEDIUMINT UNSIGNED, subState BIT, OUT dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
/*
Internal procedure to start a workflow from either the user or a spawned workflow.  This procedure is recusrive
with dfa.processSubActions, meaning that a workflow may recursively spawn an arbritrary tree of workflows.
*/
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
CREATE PROCEDURE dfa.sp_startWorkflow(workflowTyp INT, commentTx MEDIUMTEXT, modBy VARCHAR(32), raiseError BIT, OUT dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
/*
The application entry point to start a new workflow.  The id of the created workflow is returned via
OUT parameter dfaWorkflowId.  This OUT parameter may be NULL if no workflow is created and raiseError = false,
indicating the user lacked rights to start the workflow.  If @dfa_act_state_ref_id >= 0 when this proc is called, all
newly created workflows (along with their states) will be inserted into the per-connection view ref_dfa_constraint
with ref_data_constraint.REF_ID = @dfa_act_state_ref_id.
*/
	CALL dfa.sp_do_startWorkflow(workflowTyp, commentTx, modBy, raiseError, 0, NULL, NULL, FALSE, dfaWorkflowId);
END GO
delimiter ;

grant ALL on dfa.sp_startWorkflow to dfa_user;

DROP PROCEDURE IF EXISTS dfa.sp_processValidRefConstraints;
delimiter GO
CREATE PROCEDURE dfa.sp_processValidRefConstraints(applicationId INT, refId MEDIUMINT) 
	MODIFIES SQL DATA
BEGIN
insert into ref_dfa_constraint (REF_ID,CONSTRAINT_ID,ALLOW_UPDATE,IS_RESPONSIBLE)
SELECT refId as REF_ID, LKUP_CONSTRAINT_APP.CONSTRAINT_ID, 
	case when LKUP_CONSTRAINT_APP.ROLE_COUNT = 0 OR exists (
			select * FROM LKUP_CONSTRAINT_APP_ROLE JOIN session_user_role ON session_user_role.ROLE_NM = LKUP_CONSTRAINT_APP_ROLE.ROLE_NM
				WHERE IS_UPDATE=1 AND LKUP_CONSTRAINT_APP_ROLE.APPLICATION_ID = LKUP_CONSTRAINT_APP.APPLICATION_ID AND LKUP_CONSTRAINT_APP_ROLE.CONSTRAINT_ID = LKUP_CONSTRAINT_APP		
    ) THEN TRUE ELSE FALSE END
     as ALLOW_UPDATE, 
	0 as IS_RESPONSIBLE
	from LKUP_CONSTRAINT_APP where LKUP_CONSTRAINT_APP.APPLICATION_ID = applicationId
		AND (LKUP_CONSTRAINT_APP.ROLE_COUNT = 0 OR EXISTS (
			select * FROM LKUP_CONSTRAINT_APP_ROLE JOIN session_user_role ON session_user_role.ROLE_NM = LKUP_CONSTRAINT_APP_ROLE.ROLE_NM
				WHERE IS_SHOW=1 AND LKUP_CONSTRAINT_APP_ROLE.APPLICATION_ID = LKUP_CONSTRAINT_APP.APPLICATION_ID AND LKUP_CONSTRAINT_APP_ROLE.CONSTRAINT_ID = LKUP_CONSTRAINT_APP
        ))
        AND (LKUP_CONSTRAINT_APP.FIELD_COUNT = 0 OR LKUP_CONSTRAINT_APP.FIELD_COUNT = 
        /* This works because triggers enforce the fact that neither LKUP_CONSTRAINT_FIELD_INT_RANGE 
			nor LKUP_CONSTRAINT_FIELD_DATE_RANGE contain overlapping values, so only 1 row from each 
            will match. */
			(select count(DISTINCT LKUP_CONSTRAINT_APP_FIELD.FIELD_ID) from LKUP_CONSTRAINT_APP_FIELD JOIN LKUP_FIELD ON LKUP_CONSTRAINT_APP_FIELD.FIELD_ID = LKUP_FIELD.FIELD_ID
				LEFT JOIN session_dfa_field_value ON session_dfa_field_value.FIELD_ID = LKUP_CONSTRAINT_APP_FIELD.FIELD_ID
                LEFT JOIN LKUP_CONSTRAINT_FIELD_INT_RANGE ON LKUP_FIELD.FIELD_TYP_ID = 1 AND session_dfa_field_value.INT_VALUE IS NOT NULL 
					AND LKUP_CONSTRAINT_FIELD_INT_RANGE.FIELD_ID = LKUP_CONSTRAINT_APP_FIELD.FIELD_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.APPLICATION_ID = LKUP_CONSTRAINT_FIELD_INT_RANGE.APPLICATION_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.CONSTRAINT_ID = LKUP_CONSTRAINT_FIELD_INT_RANGE.CONSTRAINT_ID AND
					session_dfa_field_value.INT_VALUE BETWEEN LKUP_CONSTRAINT_FIELD_INT_RANGE.SMALLEST_VALUE AND RANGE_TABLE.LARGEST_VALUE
                LEFT JOIN LKUP_CONSTRAINT_FIELD_DATE_RANGE ON LKUP_FIELD.FIELD_TYP_ID = 3 AND session_dfa_field_value.DATE_VALUE IS NOT NULL 
					AND LKUP_CONSTRAINT_FIELD_DATE_RANGE.FIELD_ID = LKUP_CONSTRAINT_APP_FIELD.FIELD_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.APPLICATION_ID = LKUP_CONSTRAINT_FIELD_DATE_RANGE.APPLICATION_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.CONSTRAINT_ID = LKUP_CONSTRAINT_FIELD_DATE_RANGE.CONSTRAINT_ID AND
					session_dfa_field_value.DATE_VALUE BETWEEN LKUP_CONSTRAINT_FIELD_DATE_RANGE.SMALLEST_VALUE AND LKUP_CONSTRAINT_FIELD_DATE_RANGE.LARGEST_VALUE
                LEFT JOIN LKUP_CONSTRAINT_FIELD_BIT ON LKUP_FIELD.FIELD_TYP_ID = 2 AND session_dfa_field_value.BIT_VALUE IS NOT NULL
					AND LKUP_CONSTRAINT_FIELD_BIT.FIELD_ID = LKUP_CONSTRAINT_APP_FIELD.FIELD_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.APPLICATION_ID = LKUP_CONSTRAINT_FIELD_BIT.APPLICATION_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.CONSTRAINT_ID = LKUP_CONSTRAINT_FIELD_BIT.CONSTRAINT_ID AND
					(LKUP_CONSTRAINT_FIELD_BIT.VALID_VALUE IS NULL OR LKUP_CONSTRAINT_FIELD_BIT.VALID_VALUE = session_dfa_field_value.BIT_VALUE)
				WHERE ((LKUP_CONSTRAINT_APP_FIELD.NULL_VALID = 1 
					AND session_dfa_field_value.INT_VALUE IS NULL
                    AND session_dfa_field_value.DATE_VALUE IS NULL
                    AND session_dfa_field_value.BIT_VALUE IS NULL)
					OR LKUP_CONSTRAINT_FIELD_INT_RANGE.FIELD_ID IS NOT NULL
					OR LKUP_CONSTRAINT_FIELD_DATE_RANGE.FIELD_ID IS NOT NULL
					OR LKUP_CONSTRAINT_FIELD_BIT.FIELD_ID IS NOT NULL)
                    AND LKUP_CONSTRAINT_APP_FIELD.APPLICATION_ID = LKUP_CONSTRAINT_APP.APPLICATION_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.CONSTRAINT_ID = LKUP_CONSTRAINT_APP.CONSTRAINT_ID
        ));

-- OK, now update the responsible flag with roles that grant this.  This update allows duplicates, but they
-- are harmless because they update IS_RESPONSIBLE to the value it already has.

	update ref_dfa_constraint, LKUP_CONSTRAINT_APP_ROLE, session_user_role
		SET ref_dfa_constraint.IS_RESPONSIBLE = 1
        WHERE ref_dfa_constraint.ALLOW_UPDATE = 1 AND LKUP_CONSTRAINT_APP_ROLE.IS_RESPONSIBLE = 1
			and ref_dfa_constraint.REF_ID = refId
            and ref_dfa_constraint.CONSTRAINT_ID = LKUP_CONSTRAINT_APP_ROLE.CONSTRAINT_ID
            and LKUP_CONSTRAINT_APP_ROLE.APPLICATION_ID = applicationId
            and LKUP_CONSTRAINT_APP_ROLE = session_user_role.role_name;

END GO
delimiter ;

DROP PROCEDURE IF EXISTS dfa.sp_processValidConstraints;
delimiter GO
CREATE PROCEDURE dfa.sp_processValidConstraints(applicationId INT) 
	MODIFIES SQL DATA
BEGIN
/********************************************
Preconditions: session_dfa_field_value and session_user_role
are populated with the field values for the application
and the user roles.

Postcondition: session_dfa_constraint will be populated
with normal satisfied constraints, while ref_dfa_constraint
with REF_ID = 1 will be populated by system satisfied
constraints (the session constraints + 'SYSTEM' role
added).
*********************************************/

delete from ref_dfa_constraint where REF_ID IN (0,1)
	and ref_dfa_constraint.CONSTRAINT_ID IN (select CONSTRAINT_ID from LKUP_CONSTRAINT_APP where APPLICATION_ID = applicationId);

CALL sp_processValidRefConstraints(applicationId, 0);
IF exists (select * from session_user_role where session_user_role.role_nm = 'SYSTEM') THEN
-- System already present, copy the primary constraints to the system constraints.
	INSERT INTO ref_dfa_constraint (REF_ID,CONSTRAINT_ID,ALLOW_UPDATE,IS_RESPONSIBLE)
    select 1, CONSTRAINT_ID, ALLOW_UPDATE,IS_RESPONSIBLE from session_dfa_constraint;
ELSE
-- Temporarly add system to session role table, compute roles for refid 1, and then remove system role.
	insert into session_user_role (ROLE_NM) VALUES ('SYSTEM');
    CALL sp_processValidRefConstraints(applicationId, 1);
    delete from session_user_role where ROLE_NM='SYSTEM';
END IF;

END GO
delimiter ;

grant ALL on dfa.sp_processValidConstraints to dfa_view;

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
