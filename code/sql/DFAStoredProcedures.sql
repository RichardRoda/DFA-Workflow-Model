
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
		from LKUP_WORKFLOW_STATE_TYP_CREATE JOIN ref_dfa_constraint ON ref_dfa_constraint.DFA_WORKFLOW_ID = spawnDfaWorkflowId AND REF_ID = 1 AND ref_dfa_constraint.CONSTRAINT_ID = LKUP_WORKFLOW_STATE_TYP_CREATE.CONSTRAINT_ID
        where ref_dfa_constraint.ALLOW_UPDATE = 1 AND LKUP_WORKFLOW_STATE_TYP_CREATE.STATE_TYP = stateTyp ORDER BY LKUP_WORKFLOW_STATE_TYP_CREATE.WORKFLOW_TYP;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET cursor_done = TRUE;

	IF EXISTS (select 1 from LKUP_WORKFLOW_STATE_TYP_CREATE JOIN DFA_WORKFLOW_STATE ON LKUP_WORKFLOW_STATE_TYP_CREATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP
		JOIN ref_dfa_constraint ON ref_dfa_constraint.DFA_WORKFLOW_ID = spawnDfaWorkflowId AND REF_ID = 1 AND ref_dfa_constraint.CONSTRAINT_ID = LKUP_WORKFLOW_STATE_TYP_CREATE.CONSTRAINT_ID
		WHERE ref_dfa_constraint.ALLOW_UPDATE = 1 AND DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = spawnDfaWorkflowId AND DFA_WORKFLOW_STATE.DFA_STATE_ID <> originalDfaStateId AND IS_CURRENT = 1) THEN

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
    DECLARE updateAllowed BIT DEFAULT FALSE;
    
/* Change the reserved */

    CALL dfa.sp_processNewDfaDataAndConstraints(workflowTyp);
	SET updateAllowed = EXISTS (select * from ref_dfa_constraint join LKUP_WORKFLOW_TYP ON 
		LKUP_WORKFLOW_TYP.CONSTRAINT_ID = ref_dfa_constraint.CONSTRAINT_ID
        where DFA_WORKFLOW_ID = 1 AND REF_ID = refConstraintId and ALLOW_UPDATE=1);
        
	-- Cleanup references to reserved workflow #1.
    delete from ref_dfa_constraint where DFA_WORKFLOW_ID=1 AND REF_ID IN (0,1);
    delete from ref_dfa_workflow_state where DFA_WORKFLOW_ID=1 AND REF_ID IN (0,1);
    delete from session_dfa_field_value where DFA_WORKFLOW_ID=1;

	IF updateAllowed THEN
		INSERT INTO DFA_WORKFLOW (WORKFLOW_TYP,COMMENT_TX,MOD_BY,SPAWN_DFA_WORKFLOW_ID,SPAWN_DFA_STATE_ID,SUB_STATE)
			VALUES (workflowTyp, commentTx, modBy,spawnDfaWorkflowId,spawnDfaStateId,subState);	

		SET dfaWorkflowId =  LAST_INSERT_ID();
		CALL dfa.sp_processDfaDataAndConstraints(dfaWorkflowId);
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

grant EXECUTE ON PROCEDURE dfa.sp_startWorkflow to dfa_user;

DROP PROCEDURE IF EXISTS dfa.sp_processValidRefConstraints;
delimiter GO
CREATE PROCEDURE dfa.sp_processValidRefConstraints(applicationId INT, workflowId BIGINT UNSIGNED, refId MEDIUMINT) 
	MODIFIES SQL DATA
BEGIN
insert into ref_dfa_constraint (REF_ID,DFA_WORKFLOW_ID,CONSTRAINT_ID,ALLOW_UPDATE,IS_RESPONSIBLE)
SELECT refId as REF_ID, session_dfa_workflow.DFA_WORKFLOW_ID, LKUP_CONSTRAINT_APP.CONSTRAINT_ID, 
    CASE WHEN LKUP_CONSTRAINT_APP.ROLE_COUNT = 0 THEN 1 ELSE 0 END as ALLOW_UPDATE, 0 as IS_RESPONSIBLE
	from LKUP_CONSTRAINT_APP JOIN session_dfa_workflow ON (workflowId IS NULL OR session_dfa_workflow.DFA_WORKFLOW_ID = workflowId)
	where LKUP_CONSTRAINT_APP.APPLICATION_ID = applicationId AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID <> 2
		AND (LKUP_CONSTRAINT_APP.ROLE_COUNT = 0 OR EXISTS (
			select * FROM LKUP_CONSTRAINT_APP_ROLE JOIN session_user_role ON session_user_role.ROLE_NM = LKUP_CONSTRAINT_APP_ROLE.ROLE_NM
				WHERE IS_SHOW=1 AND LKUP_CONSTRAINT_APP_ROLE.APPLICATION_ID = LKUP_CONSTRAINT_APP.APPLICATION_ID AND LKUP_CONSTRAINT_APP_ROLE.CONSTRAINT_ID = LKUP_CONSTRAINT_APP.CONSTRAINT_ID
        ))
        AND (LKUP_CONSTRAINT_APP.FIELD_COUNT = 0 OR LKUP_CONSTRAINT_APP.FIELD_COUNT = 
        /* This works because triggers enforce the fact that neither LKUP_CONSTRAINT_FIELD_INT_RANGE 
			nor LKUP_CONSTRAINT_FIELD_DATE_RANGE contain overlapping values, so only 1 row from each 
            will match. */
			(select count(DISTINCT LKUP_CONSTRAINT_APP_FIELD.FIELD_ID) 
				from LKUP_CONSTRAINT_APP_FIELD JOIN LKUP_FIELD ON LKUP_CONSTRAINT_APP_FIELD.FIELD_ID = LKUP_FIELD.FIELD_ID
				JOIN session_dfa_field_value ON session_dfa_field_value.FIELD_ID = LKUP_CONSTRAINT_APP_FIELD.FIELD_ID
                LEFT JOIN LKUP_CONSTRAINT_FIELD_INT_RANGE ON LKUP_FIELD.FIELD_TYP_ID = 1 
					AND session_dfa_field_value.INT_VALUE IS NOT NULL 
					AND LKUP_CONSTRAINT_FIELD_INT_RANGE.FIELD_ID = LKUP_CONSTRAINT_APP_FIELD.FIELD_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.APPLICATION_ID = LKUP_CONSTRAINT_FIELD_INT_RANGE.APPLICATION_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.CONSTRAINT_ID = LKUP_CONSTRAINT_FIELD_INT_RANGE.CONSTRAINT_ID AND
					session_dfa_field_value.INT_VALUE BETWEEN LKUP_CONSTRAINT_FIELD_INT_RANGE.SMALLEST_VALUE 
                    AND LKUP_CONSTRAINT_FIELD_INT_RANGE.LARGEST_VALUE
                LEFT JOIN LKUP_CONSTRAINT_FIELD_DATE_RANGE ON LKUP_FIELD.FIELD_TYP_ID = 3 
					AND session_dfa_field_value.DATE_VALUE IS NOT NULL 
					AND LKUP_CONSTRAINT_FIELD_DATE_RANGE.FIELD_ID = LKUP_CONSTRAINT_APP_FIELD.FIELD_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.APPLICATION_ID = LKUP_CONSTRAINT_FIELD_DATE_RANGE.APPLICATION_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.CONSTRAINT_ID = LKUP_CONSTRAINT_FIELD_DATE_RANGE.CONSTRAINT_ID AND
					session_dfa_field_value.DATE_VALUE BETWEEN LKUP_CONSTRAINT_FIELD_DATE_RANGE.SMALLEST_VALUE 
                    AND LKUP_CONSTRAINT_FIELD_DATE_RANGE.LARGEST_VALUE
                LEFT JOIN LKUP_CONSTRAINT_FIELD_BIT ON LKUP_FIELD.FIELD_TYP_ID = 2 
					AND session_dfa_field_value.BIT_VALUE IS NOT NULL
					AND LKUP_CONSTRAINT_FIELD_BIT.FIELD_ID = LKUP_CONSTRAINT_APP_FIELD.FIELD_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.APPLICATION_ID = LKUP_CONSTRAINT_FIELD_BIT.APPLICATION_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.CONSTRAINT_ID = LKUP_CONSTRAINT_FIELD_BIT.CONSTRAINT_ID AND
					(LKUP_CONSTRAINT_FIELD_BIT.VALID_VALUE IS NULL OR 
						LKUP_CONSTRAINT_FIELD_BIT.VALID_VALUE = session_dfa_field_value.BIT_VALUE)
				WHERE ((LKUP_CONSTRAINT_APP_FIELD.NULL_VALID = 1 
					AND session_dfa_field_value.INT_VALUE IS NULL
                    AND session_dfa_field_value.DATE_VALUE IS NULL
                    AND session_dfa_field_value.BIT_VALUE IS NULL)
					OR LKUP_CONSTRAINT_FIELD_INT_RANGE.FIELD_ID IS NOT NULL
					OR LKUP_CONSTRAINT_FIELD_DATE_RANGE.FIELD_ID IS NOT NULL
					OR LKUP_CONSTRAINT_FIELD_BIT.FIELD_ID IS NOT NULL)
                    AND LKUP_CONSTRAINT_APP_FIELD.APPLICATION_ID = LKUP_CONSTRAINT_APP.APPLICATION_ID 
                    AND LKUP_CONSTRAINT_APP_FIELD.CONSTRAINT_ID = LKUP_CONSTRAINT_APP.CONSTRAINT_ID
                    AND session_dfa_field_value.DFA_WORKFLOW_ID = session_dfa_workflow.DFA_WORKFLOW_ID
        ));

-- OK, now update the updatable and responsible flag with roles that grant this.  This update allows duplicates, but they
-- are harmless because they update IS_RESPONSIBLE to the value it already has.
	update ref_dfa_constraint, LKUP_CONSTRAINT_APP_ROLE, session_user_role
		SET ref_dfa_constraint.ALLOW_UPDATE = 1
        WHERE LKUP_CONSTRAINT_APP_ROLE.ALLOW_UPDATE = 1
			and ref_dfa_constraint.REF_ID = refId
            and ref_dfa_constraint.DFA_WORKFLOW_ID = workflowId
            and ref_dfa_constraint.CONSTRAINT_ID = LKUP_CONSTRAINT_APP_ROLE.CONSTRAINT_ID
            and LKUP_CONSTRAINT_APP_ROLE.APPLICATION_ID = applicationId
            and LKUP_CONSTRAINT_APP_ROLE.ROLE_NM = session_user_role.ROLE_NM;

	update ref_dfa_constraint, LKUP_CONSTRAINT_APP_ROLE, session_user_role
		SET ref_dfa_constraint.IS_RESPONSIBLE = 1
        WHERE ref_dfa_constraint.ALLOW_UPDATE = 1 AND LKUP_CONSTRAINT_APP_ROLE.IS_RESPONSIBLE = 1
			and ref_dfa_constraint.REF_ID = refId
            and ref_dfa_constraint.DFA_WORKFLOW_ID = workflowId
            and ref_dfa_constraint.CONSTRAINT_ID = LKUP_CONSTRAINT_APP_ROLE.CONSTRAINT_ID
            and LKUP_CONSTRAINT_APP_ROLE.APPLICATION_ID = applicationId
            and LKUP_CONSTRAINT_APP_ROLE.ROLE_NM = session_user_role.ROLE_NM;

END GO
delimiter ;

drop procedure if exists dfa.sp_execUntrustedApplicationDataProc;
delimiter GO
CREATE DEFINER=dfadataexecutor@localhost PROCEDURE dfa.sp_execUntrustedApplicationDataProc(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
/***************************************************************
This procedure exists to prevent a conniving DFA user from gaining
root database rights by defining a stored procedure with SQL SECURITY
of INVOKER and setting the application_data_populate_proc prepared
statement to invoke that proc.  Instead, such a proc will run as
the dfadataexecutor@localhost account.  Any stored procedure
called by the application_data_populate_proc prepared statement
must GRANT EXECUTE ON PRODECURE <app proc name> to dfadataexecutor@localhost

An application proc with security context of DEFINER will run
normally, which is the purpose of this exercise: to discourage
use of INVOKER.
***************************************************************/
-- Workaround for fact that mariaDB does not support local variables.
-- Use fully qualified variable name to avoid collisions in global space.
	SET @dfaSpProcessValidConstraintsDfaWorkflowId = dfaWorkflowId;
	execute application_data_populate_proc using @dfaSpProcessValidConstraintsDfaWorkflowId;
END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_execUntrustedApplicationDataProc to dfadataexecutor@localhost;

DROP PROCEDURE IF EXISTS dfa.sp_processValidConstraints;
delimiter GO
CREATE PROCEDURE dfa.sp_processValidConstraints(applicationId INT, dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
/********************************************
Preconditions: session_dfa_field_value and session_user_role
are populated with the field values for the application
and the user roles.  session_dfa_workflow_state should be
populated with the DFA_WORKFLOWS to process.
application_data_populate_proc is a prepared statement
of a stored procedure call that accepts the workflowId passed
into this proc.  This proc must have a
GRANT EXECUTE ON PRODECURE <app proc name> to dfadataexecutor@localhost.
@dfa_user_application_id is the application
id of the using application.

Postcondition: session_dfa_constraint will be populated
with normal satisfied constraints, while ref_dfa_constraint
with REF_ID = 1 will be populated by system satisfied
constraints (the session constraints + 'SYSTEM' role
added).
*********************************************/

delete from ref_dfa_constraint where REF_ID IN (0,1) AND (dfaWorkflowId IS NULL or ref_dfa_constraint.DFA_WORKFLOW_ID = dfaWorkflowId)
	and ref_dfa_constraint.CONSTRAINT_ID IN (select CONSTRAINT_ID from LKUP_CONSTRAINT_APP where APPLICATION_ID = applicationId);

CALL dfa.sp_processValidRefConstraints(applicationId, dfaWorkflowId, 0);
IF exists (select * from session_user_role where session_user_role.role_nm = @dfa_system_role_nm) THEN
-- Magically add the DFA system constraint here.
	INSERT INTO session_dfa_constraint (DFA_WORKFLOW_ID,CONSTRAINT_ID,ALLOW_UPDATE,IS_RESPONSIBLE)
    select DFA_WORKFLOW_ID,2 as CONSTRAINT_ID,1 AS ALLOW_UPDATE, 0 as IS_RESPONSIBLE
	from session_dfa_workflow LEFT JOIN session_dfa_constraint ON session_dfa_constraint.DFA_WORKFLOW_ID=session_dfa_workflow.DFA_WORKFLOW_ID and session_dfa_constraint.CONSTRAINT_ID=2
	where session_dfa_constraint.CONSTRAINT_ID IS NULL AND (dfaWorkflowId IS NULL OR session_dfa_workflow.DFA_WORKFLOW_ID = dfaWorkflowId);

-- System already present, copy the primary constraints to the system constraints.
	INSERT INTO ref_dfa_constraint (REF_ID,DFA_WORKFLOW_ID,CONSTRAINT_ID,ALLOW_UPDATE,IS_RESPONSIBLE)
    select 1,DFA_WORKFLOW_ID, CONSTRAINT_ID, ALLOW_UPDATE,IS_RESPONSIBLE from session_dfa_constraint;
ELSE
-- Temporarly add system to session role table, compute roles for refid 1, and then remove system role.
	insert into session_user_role (ROLE_NM) VALUES (@dfa_system_role_nm);
    CALL dfa.sp_processValidRefConstraints(applicationId, dfaWorkflowId, 1);
    delete from session_user_role where ROLE_NM=@dfa_system_role_nm;
-- Magically add the DFA system constraint here.
INSERT INTO ref_dfa_constraint (REF_ID,DFA_WORKFLOW_ID,CONSTRAINT_ID,ALLOW_UPDATE,IS_RESPONSIBLE)
	select 1,session_dfa_workflow.DFA_WORKFLOW_ID,2 as CONSTRAINT_ID,1 AS ALLOW_UPDATE, 0 as IS_RESPONSIBLE
	from session_dfa_workflow LEFT JOIN ref_dfa_constraint ON ref_dfa_constraint.REF_ID=1 AND ref_dfa_constraint.DFA_WORKFLOW_ID=session_dfa_workflow.DFA_WORKFLOW_ID and ref_dfa_constraint.CONSTRAINT_ID=2
	where ref_dfa_constraint.CONSTRAINT_ID IS NULL AND (dfaWorkflowId IS NULL OR session_dfa_workflow.DFA_WORKFLOW_ID = dfaWorkflowId);

END IF;

END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_processValidConstraints to dfa_viewer;

drop procedure if exists dfa.sp_processDfaDataForExisting;
delimiter GO
CREATE PROCEDURE dfa.sp_processDfaDataForExisting(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
	delete from session_dfa_field_value where FIELD_ID IN (1,2,3,4)
		AND (dfaWorkflowId IS NULL OR DFA_WORKFLOW_ID = dfaWorkflowId);

insert into session_dfa_field_value (DFA_WORKFLOW_ID,FIELD_ID,INT_VALUE,BIT_VALUE,DATE_VALUE,CHAR_VALUE)
select session_dfa_workflow.DFA_WORKFLOW_ID, LKUP_FIELD.FIELD_ID
, case when LKUP_FIELD.FIELD_TYP_ID <> 1 THEN null
	WHEN LKUP_FIELD.FIELD_ID =  2 THEN DFA_WORKFLOW_STATE.STATE_TYP
	WHEN LKUP_FIELD.FIELD_ID =  3 THEN DFA_WORKFLOW_STATE.EVENT_TYP
	WHEN LKUP_FIELD.FIELD_ID =  4 THEN DFA_WORKFLOW.WORKFLOW_TYP
    ELSE NULL END as INT_VALUE

, case when LKUP_FIELD.FIELD_TYP_ID <> 2 THEN null
	WHEN LKUP_FIELD.FIELD_ID = 1 THEN NOT ISNULL(DFA_WORKFLOW_STATE.UNDO_STATE_ID)
    ELSE NULL END as BIT_VALUE

, case when LKUP_FIELD.FIELD_TYP_ID <> 3 THEN null
	WHEN FALSE THEN NULL
    ELSE NULL END as DATE_VALUE

, NULL as CHAR_VALUE

from session_dfa_workflow JOIN LKUP_FIELD ON LKUP_FIELD.FIELD_ID IN (1,2,3,4)
	left join DFA_WORKFLOW ON LKUP_FIELD.ENTITY_ID = 2 AND DFA_WORKFLOW.DFA_WORKFLOW_ID = session_dfa_workflow.DFA_WORKFLOW_ID
    left join DFA_WORKFLOW_STATE ON LKUP_FIELD.ENTITY_ID = 1 AND DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = session_dfa_workflow.DFA_WORKFLOW_ID AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
where dfaWorkflowId IS NULL OR session_dfa_workflow.DFA_WORKFLOW_ID = dfaWorkflowId;    
END GO
delimiter ;

drop procedure if exists dfa.sp_processAppDataConstraints;
delimiter GO
CREATE PROCEDURE dfa.sp_processAppDataConstraints(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
declare noWorkflowInState BIT default false;
set noWorkflowInState = dfaWorkflowId IS NOT NULL AND NOT EXISTS (select * from session_dfa_workflow_state where DFA_WORKFLOW_ID = dfaWorkflowId);

if (noWorkflowInState) THEN
	insert into session_dfa_workflow_state (DFA_WORKFLOW_ID, DFA_STATE_ID) VALUES (dfaWorkflowId, 1);
END IF;
    
CALL dfa.sp_processValidConstraints(1, dfaWorkflowId);

IF (@dfa_user_application_id IS NOT NULL) THEN
	CALL dfa.sp_execUntrustedApplicationDataProc(dfaWorkflowId);
	CALL dfa.sp_processValidConstraints(@dfa_user_application_id, dfaWorkflowId);
END IF;

if (noWorkflowInState) THEN
	delete from session_dfa_workflow_state where DFA_WORKFLOW_ID = dfaWorkflowId and DFA_STATE_ID=1;
END IF;

END GO
delimiter ;


drop procedure if exists dfa.sp_processDfaDataAndConstraints;
delimiter GO
CREATE PROCEDURE dfa.sp_processDfaDataAndConstraints(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN

declare needsWorkflowId BIT DEFAULT false;

set needsWorkflowId = dfaWorkflowId IS NOT NULL AND 
	not exists (select * from session_dfa_workflow_state where DFA_WORKFLOW_ID = dfaWorkflowId) AND
    exists (select * from DFA_WORKFLOW_STATE where DFA_WORKFLOW_ID = dfaWorkflowId AND DFA_STATE_ID=1);

IF needsWorkflowId THEN
	insert into session_dfa_workflow_state (DFA_WORKFLOW_ID, DFA_STATE_ID, OUTPUT)
    VALUES (dfaWorkflowId, 1, 0);
END IF;

CALL dfa.sp_processDfaDataForExisting(dfaWorkflowId);
CALL dfa.sp_processAppDataConstraints(dfaWorkflowId);

IF needsWorkflowId THEN
	delete from session_dfa_workflow_state where DFA_WORKFLOW_ID = dfaWorkflowId AND DFA_STATE_ID=1;
END IF;

END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_processDfaDataAndConstraints to dfa_viewer;

drop procedure if exists dfa.sp_processNewDfaDataAndConstraints;
delimiter GO
CREATE PROCEDURE dfa.sp_processNewDfaDataAndConstraints(dfaWorkflowTyp INT) 
	MODIFIES SQL DATA
BEGIN

declare needsWorkflowId BIT DEFAULT false;

set needsWorkflowId =  not exists (select * from session_dfa_workflow_state where DFA_WORKFLOW_ID = 1) AND
    exists (select * from DFA_WORKFLOW_STATE where DFA_WORKFLOW_ID = 1 AND DFA_STATE_ID=1);

IF needsWorkflowId THEN
	insert into session_dfa_workflow_state (DFA_WORKFLOW_ID, DFA_STATE_ID, OUTPUT)
    VALUES (1, 1, 0);
END IF;

delete from session_dfa_field_value where FIELD_ID IN (1,2,3,4) AND DFA_WORKFLOW_ID = 1;

insert into session_dfa_field_value (DFA_WORKFLOW_ID,FIELD_ID,BIT_VALUE)
VALUES (1, 1, 0); -- Not undoable.

insert into session_dfa_field_value (DFA_WORKFLOW_ID,FIELD_ID,INT_VALUE)
select 1, 2, START_STATE_TYP from LKUP_WORKFLOW_TYP where LKUP_WORKFLOW_TYP.WORKFLOW_TYP = dfaWorkflowTyp;

insert into session_dfa_field_value (DFA_WORKFLOW_ID,FIELD_ID,INT_VALUE)
select 1, 3, START_EVENT_TYP from LKUP_WORKFLOW_TYP where LKUP_WORKFLOW_TYP.WORKFLOW_TYP = dfaWorkflowTyp;

insert into session_dfa_field_value (DFA_WORKFLOW_ID,FIELD_ID,INT_VALUE)
VALUES (1, 4, dfaWorkflowTyp); -- The new workflow type.

CALL dfa.sp_processAppDataConstraints(1);

IF needsWorkflowId THEN
	delete from session_dfa_workflow_state where DFA_WORKFLOW_ID = 1 AND DFA_STATE_ID=1;
END IF;

END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_processNewDfaDataAndConstraints to dfa_viewer;

drop procedure if exists dfa.sp_processNullApplicationData;
delimiter GO
CREATE PROCEDURE dfa.sp_processNullApplicationData(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
/**********************************************************
This is a no-op proc for applications that have constraints
that depend solely on the state of the DFA graph and need to
be re-populated when state changes. 
**********************************************************/
END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_processNullApplicationData to dfadataexecutor@localhost;

drop procedure if exists dfa.sp_cleanupSessionData;
delimiter GO
CREATE PROCEDURE dfa.sp_cleanupSessionData() 
	MODIFIES SQL DATA
BEGIN

delete from ref_dfa_constraint where 1=1;
delete from ref_dfa_workflow_state where 1=1;
delete from session_dfa_field_value where 1=1;

END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_cleanupSessionData to dfa_viewer;

drop procedure if exists dfa.sp_cleanupSessionDataAndRoles;
delimiter GO
CREATE PROCEDURE dfa.sp_cleanupSessionDataAndRoles() 
	MODIFIES SQL DATA
BEGIN

call dfa.sp_cleanupSessionData();
delete from ref_user_role where 1=1;

END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_cleanupSessionDataAndRoles to dfa_viewer;

drop procedure if exists dfa.sp_configureForApplication;
delimiter GO
CREATE PROCEDURE dfa.sp_configureForApplication(applicationId INT, recordStatesToRefId INT, systemRoleName VARCHAR(128), dataPopulateCallStatement VARCHAR(128)) 
BEGIN
/**********************************************************
Configure DFA database session for application using DFA
framework.  applicationId is required and corresponds to
your application in LKUP_APPLICATION.  systemRoleName is
optional.  If NULL is passed in, 'SYSTEM' will be used.
recordStatesToRefId is the refId used in 
ref_dfa_workflow_state.REF_ID to automatically record
any new dfa states (including new workflows).  If NULL
or < 0, no states are recorded.  If 0, new states are visible
to view session_dfa_workflow_state.  New states are created
with OUTPUT=1 to distinguish them from incoming workflows
and states.
dataPopulateCallStatement is a stored procedure that is
used to update the application's data when a DFAs state
changes.  It will have the dfaWorkflowId from 
dfa.sp_processDfaDataAndConstraints passed into it and 
should have syntax like 'CALL myAppsDataUpdateProc(?)'
Internally, this proc creates a prepared statement that
will be used to execute the proc provided.

The dataPopulateCallStatement proc must have execute 
permission granted to the dfadataexecutor@localhost user.
The proc runs in that user's context.  This is to prevent
an evil user from running commmands as root by supplying
a proc that has the SQL SECURITY INVOKER characteristic.

**********************************************************/
IF (applicationId IS NULL) THEN
	SIGNAL SQLSTATE '45000' SET message_text='Application ID is required (may not be null).';
ELSEIF (applicationId = 1) THEN
	SIGNAL SQLSTATE '45000' SET message_text='Application ID 1 is reserved for the DFA framework.';
ELSEIF NOT EXISTS (select * from LKUP_APPLICATION where APPLICATION_ID = applicationId) THEN
	SIGNAL SQLSTATE '45000' SET message_text='Application id not found in LKUP_APPLICATION.';
ELSE

SET @dfa_user_application_id = applicationId;

IF (systemRoleName IS NULL) then
	SET @dfa_system_role_nm='SYSTEM';
ELSE
	SET @dfa_system_role_nm=systemRoleName;
END IF;

IF (dataPopulateCallStatement IS NULL) THEN
	SET @dfaSpProcessNullApplicationDataDataPopulateCallStatement = 'CALL dfa.sp_processNullApplicationData(?)';
else
	SET @dfaSpProcessNullApplicationDataDataPopulateCallStatement = dataPopulateCallStatement;
END IF;

set @dfa_act_state_ref_id = recordStatesToRefId;

PREPARE application_data_populate_proc FROM @dfaSpProcessNullApplicationDataDataPopulateCallStatement;

END IF;

END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_configureForApplication to dfa_viewer;

drop procedure if exists dfa.sp_findNextValidState;
delimiter GO
create procedure dfa.sp_findNextValidState(dfaWorkflowId BIGINT UNSIGNED, nextStateTyp INT, refId INT, OUT validStateTyp INT, OUT isPseudo BIT)
this_proc: BEGIN
	declare allowUpdate BIT DEFAULT NULL;
	SET validStateTyp = NULL;
	WHILE (validStateTyp IS NULL AND nextStateTyp IS NOT NULL AND (allowUpdate IS NULL OR allowUpdate <> 1)) DO
		select STATE_TYP, ALT_STATE_TYP, PSEUDO, ALLOW_UPDATE
		INTO validStateTyp, nextStateTyp, isPseudo, allowUpdate FROM LKUP_STATE 
		LEFT JOIN ref_dfa_constraint ON DFA_WORKFLOW_ID = dfaWorkflowId AND LKUP_STATE.CONSTRAINT_ID = ref_dfa_constraint.CONSTRAINT_ID AND REF_ID = refId
		WHERE STATE_TYP = nextStateTyp;
	END WHILE;
	IF (allowUpdate <> 1) THEN
		SET validStateTyp = NULL;
	END IF;
END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_findNextValidState to dfa_user;

drop procedure if exists dfa.sp_do_processWorkflowEvent;
delimiter GO
create procedure dfa.sp_do_processWorkflowEvent(workflowId BIGINT UNSIGNED
	, eventTyp INT
	, commentTx MEDIUMTEXT
	, modBy VARCHAR(32)
	, raiseError BIT
	, refId INT /* 0 for interactive, 1 for system */
	, dfaStateId MEDIUMINT/* Optional - may be null */) 
	MODIFIES SQL DATA
this_proc: BEGIN
	declare stateTyp INT default NULL;
	declare isStatePseudo BIT default 0;
	declare sendEventToParent INT DEFAULT NULL;
	declare nextStateTyp INT default NULL;
	declare workflowTyp INT default NULL;
	declare errorMsgTx VARCHAR(256) default NULL;
	declare currentDfaStateId MEDIUMINT;
	declare parentWorkflowId BIGINT UNSIGNED;
	declare parentStateId MEDIUMINT UNSIGNED;
	declare parentStateTyp INT default NULL;
	-- 0 means use value computed in trigger.
	declare undoStateId MEDIUMINT UNSIGNED default 0;
	declare thisUndoStateId MEDIUMINT UNSIGNED;
	declare isCurrent BIT;
	declare isSubstate BIT;
	
	CALL dfa.sp_processDfaDataAndConstraints(workflowId);

	-- Both load and validate permissions for workflowTyp, stateTyp, and nextStateTyp.
	select dw.WORKFLOW_TYP, dfaw.SPAWN_DFA_WORKFLOW_ID, dfaw.SPAWN_DFA_STATE_ID, dfaw.SUB_STATE
	into workflowTyp, parentWorkflowId, parentStateId, isSubstate from DFA_WORKFLOW dfaw 
		JOIN LKUP_WORKFLOW_TYP dw ON dw.WORKFLOW_TYP = dfaw.WORKFLOW_TYP
		JOIN ref_dfa_constraint rdc ON dw.CONSTRAINT_ID = rdc.CONSTRAINT_ID and rdc.DFA_WORKFLOW_ID = workflowId AND rdc.REF_ID = refId
		where dfaw.DFA_WORKFLOW_ID = workflowId;
		
	if workflowTyp IS NULL THEN
		IF (raiseError = 1) THEN
			select 'Insufficent permission or workflow not found ' + dw.WORKFLOW_NM into errorMsgTx
		from DFA_WORKFLOW dfaw 
		JOIN LKUP_WORKFLOW_TYP dw ON dw.WORKFLOW_TYP = dfaw.WORKFLOW_TYP
		JOIN ref_dfa_constraint rdc ON dw.CONSTTAINT_ID = rdc.CONSTRAINT_ID and rdc.DFA_WORKFLOW_ID = workflowId and rdc.REF_ID = refId
		where dfaw.DFA_WORKFLOW_ID = workflowId;			
		SIGNAL SQLSTATE '45000' SET message_text=errorMsgTx;
		END IF;
		LEAVE this_proc;
	END IF;

	select STATE_TYP, UNDO_STATE_ID, DFA_STATE_ID into stateTyp, thisUndoStateId, currentDfaStateId 
    from DFA_WORKFLOW_STATE 
		where DFA_WORKFLOW_ID = workflowId AND IS_CURRENT = 1;

	-- Optimistic locking: If the state of this workflow does not match the state
	-- provided by the client, it means another use or the system applied an event
	-- to this workflow.  Raise an error if this happens.	
	if (dfaStateId IS NOT NULL AND dfaStateId <> currentDfaStateId) THEN
		IF (raiseError = 1) THEN
			SIGNAL SQLSTATE '45000' SET message_text='Concurrent modification error: Another user or system has modified this record.';			
		END IF;		
		LEAVE this_proc;
	END IF;
		
	select lest.NEXT_STATE_TYP, lest.PARENT_EVENT_TYP into nextStateTyp, sendEventToParent from LKUP_EVENT_STATE_TRANS lest
		JOIN ref_dfa_constraint rdc1 ON lest.CONSTRAINT_ID = rdc1.CONSTRAINT_ID and rdc1.DFA_WORKFLOW_ID = workflowId and rdc1.REF_ID = refId
		JOIN LKUP_STATE ls ON lest.NEXT_STATE_TYP = ls.STATE_TYP
		LEFT JOIN ref_dfa_constraint rdc2 ON ls.ALT_STATE_TYP IS NULL and rdc2.DFA_WORKFLOW_ID = workflowId and rdc2.REF_ID = refId AND ls.CONSTRAINT_ID = rdc2.CONSTRAINT_ID	
		where lest.EVENT_TYP = eventTyp and lest.STATE_TYP = stateTyp and rdc1.ALLOW_UPDATE = 1
			AND (ls.ALT_STATE_TYP IS NOT NULL OR rdc2.ALLOW_UPDATE = 1);

	CALL dfa.sp_findNextValidState(workflowId, nextStateTyp, refId, nextStateTyp, isStatePseudo);

	IF nextStateTyp IS NULL THEN
		IF (raiseError = 1) THEN
			select 'Insufficent permission to tansition with event ' + LKUP_EVENT.EVENT_NM into errorMsgTx
			from LKUP_EVENT where LKUP_EVENT.EVENT_TYP = eventTyp;
			SIGNAL SQLSTATE '45000' SET message_text=errorMsgTx;
		END IF;
		LEAVE this_proc;
	END IF;

	select MAKE_CURRENT into isCurrent from LKUP_EVENT where EVENT_TYP = eventTyp;

	IF (isCurrent AND isStatePseudo) THEN	
		IF (nextStateTyp = 5000) THEN
			select STATE_TYP, UNDO_STATE_ID into nextStateTyp, undoStateId from DFA_WORKFLOW_STATE 
			where DFA_WORKFLOW_ID = workflowId AND UNDO_STATE_ID = thisUndoStateId;			
		ELSE
			SIGNAL SQLSTATE '45000' SET message_text='Unknown pseudo state.';			
		END IF;
	
	END IF;
	
-- insert the newly minted state.  This must be done before any other state processing
-- because the role / role data will change as the system recursively resolved
-- other state / substates.
	INSERT INTO DFA_WORKFLOW_STATE
	(DFA_WORKFLOW_ID, IS_CURRENT, STATE_TYP, EVENT_TYP, UNDO_STATE_ID, COMMENT_TX, MOD_BY)
	VALUES (workflowId, isCurrent, nextStateTyp, eventTyp, undoStateId, commentTx, modBy);
	DELETE FROM tmp_dfa_clear_current WHERE DFA_WORKFLOW_ID = workflowId;

	IF parentWorkflowId IS NOT NULL THEN
		-- Send the event to the parent, regardless of if we are a substate or not.
		IF (sendEventToParent IS NOT NULL) THEN
				call dfa.sp_processWorkflowEvent(parentWorkflowId, sendEventToParent, commentTx, 'SYSTEM', 0, refId, IF(isSubstate, parentStateId, NULL));
		END IF;
		IF isSubstate THEN
			select STATE_TYP into parentStateTyp from DFA_WORKFLOW_STATE where 
			DFA_WORKFLOW_ID = parentWorkflowId AND DFA_STATE_ID = parentStateId AND IS_CURRENT = 1;

			SET parentStateTyp = NULL;
			if (parentStateTyp IS NOT NULL) THEN
				-- See if there are any active states.  If not, send the event defined by LKUP_WORKFLOW_STATE_TYP_CREATE.EVENT_WHEN_SUB_COMPLETED.
				SET sendEventToParent = NULL;
				select EVENT_WHEN_SUB_COMPLETED into sendEventToParent from LKUP_WORKFLOW_STATE_TYP_CREATE 
					where STATE_TYP = parentStateTyp AND WORKFLOW_TYP = workflowTyp;
				IF (sendEventToParent IS NOT NULL AND NOT EXISTS (
					select * from DFA_WORKFLOW JOIN DFA_WORKFLOW_STATE ON 
					DFA_WORKFLOW.DFA_WORKFLOW_ID = DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID 
					and DFA_WORKFLOW_STATE.IS_CURRENT = 1
					JOIN LKUP_STATE ON LKUP_STATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP
					where DFA_WORKFLOW.SPAWN_DFA_WORKFLOW_ID = parentWorkflowId 
					and DFA_WORKFLOW.SPAWN_DFA_STATE_ID = parentStateId 
					AND LKUP_STATE.SUB_SATISFIED = 0
				)) THEN
					-- Determine if this and all other siblings are inactive.  If so, send the event.
					call dfa.sp_processWorkflowEvent(parentWorkflowId, sendEventToParent, commentTx, 'SYSTEM', 0, refId, parentStateId);	
			END IF;
			END IF;
		END IF;
	END IF;
	CALL processSubActions(workflowId, currentDfaStateId);

END GO
delimiter ;

drop procedure if exists dfa.sp_processWorkflowEvent;
delimiter GO
create procedure dfa.sp_processWorkflowEvent(workflowId BIGINT UNSIGNED
	, eventTyp INT
	, commentTx MEDIUMTEXT
	, modBy VARCHAR(32)
	, raiseError BIT
	, refId INT /* 0 for interactive, 1 for system */
	, dfaStateId MEDIUMINT/* Optional - may be null */) 
	MODIFIES SQL DATA
BEGIN
	CALL dfa.sp_do_processWorkflowEvent(workflowId, eventTyp, commentTx, modBy, raiseError, refId, dfaStateId);
    CALL dfa.sp_processDfaDataAndConstraints(workflowId);
END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_processWorkflowEvent to dfa_user;

drop procedure if exists dfa.sp_selectWorkflowStates;
delimiter GO
create procedure dfa.sp_selectWorkflowStates(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
	CALL dfa.sp_processAppDataConstraints(dfaWorkflowId);

	SELECT dws.DFA_WORKFLOW_ID, dws.DFA_STATE_ID, dws.IS_CURRENT, dws.IS_PASSIVE, dws.COMMENT_TX, dws.MOD_BY, dws.MOD_DT 
		, le.EVENT_TX, le.ATTENTION as EVENT_ATTENTION, ls.STATE_TX, ls.ATTENTION as STATE_ATTENTION
    FROM DFA_WORKFLOW_STATE dws JOIN LKUP_EVENT le ON le.EVENT_TYP = dws.EVENT_TYP
    JOIN LKUP_STATE ls ON ls.STATE_TYP = dws.STATE_TYP
    JOIN session_dfa_constraint sdc ON sdc.DFA_WORKFLOW_ID = dws.DFA_WORKFLOW_ID AND ls.CONSTRAINT_ID = sdc.CONSTRAINT_ID
    WHERE dws.DFA_WORKFLOW_ID = dfaWorkflowId 
    ORDER BY dws.DFA_STATE_ID desc;

END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_selectWorkflowStates to dfa_viewer;

drop procedure if exists dfa.sp_selectWorkflowEvents;
delimiter GO
create procedure dfa.sp_selectWorkflowEvents(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
    declare stateTyp INT;
    declare eventTyp INT;
    declare eventTx VARCHAR(60);
    declare constraintId INT;
    declare altStateTyp INT;
	declare sortOrder INT;
    declare nextStateTyp INT;
    declare isStatePseudo BIT; -- for OUT parameter that we ignore.
   
    declare cursor_done BIT default false;
    
    DECLARE next_events CURSOR FOR SELECT lest.EVENT_TYP, IFNULL(lest.EVENT_TX, le.EVENT_TX) AS EVENT_TX, lssdc.CONSTRAINT_ID, ls.ALT_STATE_TYP, IFNULL(lest.SORT_ORDER, le.SORT_ORDER), lest.NEXT_STATE_TYP
	FROM LKUP_EVENT_STATE_TRANS lest join LKUP_EVENT le ON le.EVENT_TYP = lest.EVENT_TYP
    JOIN session_dfa_constraint lestsdc ON lestsdc.CONSTRAINT_ID = lest.CONSTRAINT_ID AND lestsdc.DFA_WORKFLOW_ID = dfaWorkflowId
    JOIN LKUP_STATE ls ON lest.NEXT_STATE_TYP = ls.STATE_TYP
    LEFT JOIN session_dfa_constraint lssdc ON lssdc.CONSTRAINT_ID = ls.CONSTRAINT_ID AND lssdc.ALLOW_UPDATE=1
    WHERE lestsdc.ALLOW_UPDATE = 1 AND lest.STATE_TYP = stateTyp
		AND (ls.ALT_STATE_TYP IS NOT NULL OR lssdc.CONSTRAINT_ID IS NOT NULL);

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET cursor_done = TRUE;

    select STATE_TYP into stateTyp from DFA_WORKFLOW_STATE
		where DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = dfaWorkflowId AND IS_CURRENT = 1;

	CALL dfa.sp_processAppDataConstraints(dfaWorkflowId);

	CREATE OR REPLACE TEMPORARY TABLE SELECTED_EVENTS (
		EVENT_TYP INT NOT NULL PRIMARY KEY,
        EVENT_TX VARCHAR(60) NOT NULL,
        SORT_ORDER INT NOT NULL,
        -- For ORDER BY clause.
        INDEX (SORT_ORDER,EVENT_TX)
    )
    COLLATE='utf8_general_ci'
	ENGINE=InnoDB
	;

	OPEN next_events;
	
	read_loop: LOOP
      FETCH next_events into eventTyp, eventTx, constraintId, altStateTyp, sortOrder, nextStateTyp;
      IF cursor_done THEN
		  close next_events;
        LEAVE read_loop;
      END IF;
      IF constraintId IS NOT NULL then
		insert into SELECTED_EVENTS (EVENT_TYP,EVENT_TX,SORT_ORDER) VALUES (eventTyp, eventTx, sortOrder);
      ELSEIF altStateTyp IS NOT NULL THEN
		set altStateTyp = NULL;
      	CALL dfa.sp_findNextValidState(workflowId, nextStateTyp, 0, altStateTyp, isStatePseudo);
        IF (altStateTyp IS NOT NULL) then
			insert into SELECTED_EVENTS (EVENT_TYP,EVENT_TX,SORT_ORDER) VALUES (eventTyp, eventTx, sortOrder);			
        END IF;
      END IF;
	END LOOP;
    
    SELECT EVENT_TYP, EVENT_TX FROM SELECTED_EVENTS ORDER BY SORT_ORDER, EVENT_TX, EVENT_TYP;
    
	DROP TEMPORARY TABLE SELECTED_EVENTS;        
END GO
delimiter ;

grant EXECUTE ON PROCEDURE dfa.sp_selectWorkflowEvents to dfa_viewer;

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
CALL dfa.sp_cleanupSessionData();
CALL dfa.sp_configureForApplication(2,0,NULL,NULL);

insert into ref_dfa_constraint (REF_ID,DFA_WORKFLOW_ID,CONSTRAINT_ID,ALLOW_UPDATE) VALUES (0,1,1,1);
insert into ref_dfa_constraint (REF_ID,DFA_WORKFLOW_ID,CONSTRAINT_ID,ALLOW_UPDATE) VALUES (1,1,1,1);

select concat(convert(current_timestamp(), char), ' Test') INTO @dfa_workflow_proc_unit_test_comment;
CALL dfa.sp_startWorkflow(1,@dfa_workflow_proc_unit_test_comment, 'test', 1, @dfa_workflow_insert_ut_id);    
CALL dfa.sp_startWorkflow(2,@dfa_workflow_proc_unit_test_comment, 'test', 1, @dfa_workflow_insert_ut_id_2);

delete from ref_dfa_constraint where REF_ID IN (0,1) AND DFA_WORKFLOW_ID=1 and CONSTRAINT_ID=1;
    
CALL dfa.sp_startWorkflow(1,@dfa_workflow_proc_unit_test_comment, 'test', 0, @dfa_workflow_insert_should_be_null_1);
CALL dfa.sp_startWorkflow(1,@dfa_workflow_proc_unit_test_comment, 'test', 0, @dfa_workflow_insert_should_be_null_2);

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
CALL dfa.sp_startWorkflow(1,@dfa_workflow_proc_unit_test_comment, 'test', 1, @dfa_workflow_insert_ut_id);
*/

