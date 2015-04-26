

drop procedure if exists demo_employee.initDfaFramework;
delimiter GO
create procedure demo_employee.initDfaFramework() BEGIN
	CALL dfa.sp_configureForApplication(1000, 0, NULL, NULL);
	CALL dfa.sp_cleanupSessionDataAndRoles();
END GO
delimiter ;

grant EXECUTE ON PROCEDURE demo_employee.initDfaFramework to demo_employee_user;

drop procedure if exists demo_employee.sp_selectEmployeeWorkflows;
delimiter GO
create procedure demo_employee.sp_selectEmployeeWorkflows(refId MEDIUMINT UNSIGNED)
BEGIN
    -- Bring back the data for the application.
    SELECT sdws.DFA_WORKFLOW_ID, DFA_WORKFLOW_STATE.DFA_STATE_ID, DFA_WORKFLOW.SPAWN_DFA_WORKFLOW_ID, EMPLOYEE_PROSPECT.EMPLOYEE_ID, EMPLOYEE_PROSPECT.POSITION, EMPLOYEE_PROSPECT.LAST_NM, EMPLOYEE_PROSPECT.FIRST_NM, EMP_LKUP_STATE.state_abbr, LKUP_STATE.ACTIVE, LKUP_WORKFLOW_TYP.WORKFLOW_TX, LKUP_EVENT.EVENT_TX, LKUP_STATE.STATE_TX, IFNULL(EXPECTED_TRANS.EVENT_TX, EXPECTED_EVENT.EVENT_TX) as EXPECTED_NEXT_EVENT_TX
    FROM dfa.ref_dfa_workflow_state sdws JOIN dfa.DFA_WORKFLOW DFA_WORKFLOW ON sdws.REF_ID = refId AND sdws.DFA_WORKFLOW_ID = DFA_WORKFLOW.DFA_WORKFLOW_ID
    	join dfa.DFA_WORKFLOW_STATE DFA_WORKFLOW_STATE ON DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = sdws.DFA_WORKFLOW_ID
    	JOIN dfa.LKUP_STATE LKUP_STATE ON LKUP_STATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP
    	JOIN dfa.LKUP_EVENT LKUP_EVENT ON LKUP_EVENT.EVENT_TYP = DFA_WORKFLOW_STATE.EVENT_TYP
    	JOIN dfa.LKUP_WORKFLOW_TYP LKUP_WORKFLOW_TYP ON LKUP_WORKFLOW_TYP.WORKFLOW_TYP = DFA_WORKFLOW.WORKFLOW_TYP
        JOIN demo_employee.EMPLOYEE_PROSPECT_WORKFLOW EMPLOYEE_PROSPECT_WORKFLOW ON EMPLOYEE_PROSPECT_WORKFLOW.DFA_WORKFLOW_ID = sdws.DFA_WORKFLOW_ID
        JOIN demo_employee.EMPLOYEE_PROSPECT EMPLOYEE_PROSPECT ON EMPLOYEE_PROSPECT.EMPLOYEE_ID = EMPLOYEE_PROSPECT_WORKFLOW.EMPLOYEE_ID
		LEFT JOIN demo_employee.LKUP_STATE EMP_LKUP_STATE ON EMP_LKUP_STATE.state_id = EMPLOYEE_PROSPECT.STATE_ID
-- Required: SHOW access for workflow type and workflow state.
		JOIN dfa.ref_dfa_constraint workflow_constraint ON workflow_constraint.REF_ID = refId AND workflow_constraint.DFA_WORKFLOW_ID = sdws.DFA_WORKFLOW_ID
			AND workflow_constraint.CONSTRAINT_ID = LKUP_WORKFLOW_TYP.CONSTRAINT_ID
		JOIN dfa.ref_dfa_constraint state_constraint ON state_constraint.REF_ID = refId AND state_constraint.DFA_WORKFLOW_ID = sdws.DFA_WORKFLOW_ID
			AND state_constraint.CONSTRAINT_ID = LKUP_STATE.CONSTRAINT_ID

        LEFT JOIN dfa.LKUP_EVENT EXPECTED_EVENT ON LKUP_STATE.EXPECTED_NEXT_EVENT = EXPECTED_EVENT.EVENT_TYP
        LEFT JOIN dfa.LKUP_EVENT_STATE_TRANS EXPECTED_TRANS ON EXPECTED_TRANS.STATE_TYP = LKUP_STATE.STATE_TYP
			AND EXPECTED_TRANS.EVENT_TYP = LKUP_STATE.EXPECTED_NEXT_EVENT
	WHERE DFA_WORKFLOW_STATE.IS_CURRENT = 1;
		

	
END GO
delimiter ;

grant EXECUTE ON PROCEDURE demo_employee.sp_selectEmployeeWorkflows to demo_employee_user;

drop procedure if exists demo_employee.sp_findEmployeeWorkflows;
delimiter GO
create procedure demo_employee.sp_findEmployeeWorkflows(employeeId BIGINT UNSIGNED
	, workflowId BIGINT UNSIGNED
	, workflowTyp INT
   , active BIT
   , likeLastNm VARCHAR(64)
   , likeFirstNm VARCHAR(64)
	, likeMiddleNm VARCHAR(64)
   , likeStreetNm VARCHAR(64)
   , likeCityNm VARCHAR(64)
   , stateId SMALLINT UNSIGNED
   , phoneNum VARCHAR(20)
   , likeEmailAddr VARCHAR(64))
MODIFIES SQL DATA
BEGIN
	CALL demo_employee.initDfaFramework();

	INSERT INTO dfa.session_dfa_workflow_state
	(DFA_WORKFLOW_ID, DFA_STATE_ID)
	SELECT epw.DFA_WORKFLOW_ID, 1 
	FROM demo_employee.EMPLOYEE_PROSPECT_WORKFLOW epw
	JOIN demo_employee.EMPLOYEE_PROSPECT EMPLOYEE_PROSPECT 
		ON EMPLOYEE_PROSPECT.EMPLOYEE_ID = epw.EMPLOYEE_ID
    -- Below left joins are to only bring in these tables if the corresponding
    -- search criteria are specified.
    LEFT JOIN dfa.DFA_WORKFLOW DFA_WORKFLOW ON (workflowId IS NOT NULL) 
		AND DFA_WORKFLOW.DFA_WORKFLOW_ID = epw.DFA_WORKFLOW_ID
	LEFT JOIN dfa.DFA_WORKFLOW_STATE DFA_WORKFLOW_STATE ON active IS NOT NULL 
		AND DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = epw.DFA_WORKFLOW_ID
		AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
	LEFT JOIN dfa.LKUP_STATE LKUP_STATE ON active IS NOT NULL 
		AND LKUP_STATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP 
	WHERE (epw.DFA_WORKFLOW_ID = workflowId OR workflowId IS NULL)
      AND (workflowTyp IS NULL OR DFA_WORKFLOW.WORKFLOW_TYP = workflowTyp)
      AND (LKUP_STATE.ACTIVE IS NULL OR LKUP_STATE.ACTIVE = active)
	  AND (epw.EMPLOYEE_ID = employeeId OR employeeId IS NULL)
	  AND (EMPLOYEE_PROSPECT.LAST_NM like likeLastNm OR likeLastNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.FIRST_NM like likeFirstNm OR likeFirstNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.MIDDLE_NM like likeMiddleNm OR likeMiddleNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.STREET_NM like likeStreetNm OR likeStreetNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.CITY_NM like likeCityNm OR likeCityNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.STATE_ID = stateId OR stateId IS NULL)
	  AND (EMPLOYEE_PROSPECT.PHONE_NUM like phoneNum OR phoneNum IS NULL)
	  AND (EMPLOYEE_PROSPECT.EMAIL_ADDR like likeEmailAddr OR likeEmailAddr IS NULL)
      ;

	CALL dfa.sp_processValidConstraints(1000, NULL); 
   CALL demo_employee.sp_selectEmployeeWorkflows(0);
    
END GO
delimiter ;

grant EXECUTE ON PROCEDURE demo_employee.sp_findEmployeeWorkflows to demo_employee_user;

drop procedure if exists demo_employee.sp_findWorkflowAndCurrentSubWorkflows;
delimiter GO
create procedure demo_employee.sp_findWorkflowAndCurrentSubWorkflows(dfaWorkflowId BIGINT UNSIGNED)
MODIFIES SQL DATA
BEGIN
	CALL demo_employee.initDfaFramework();

	INSERT INTO dfa.session_dfa_workflow_state
	(DFA_WORKFLOW_ID, DFA_STATE_ID) VALUES (dfaWorkflowId, 1);
	
	INSERT INTO dfa.session_dfa_workflow_state
	(DFA_WORKFLOW_ID, DFA_STATE_ID)
	SELECT DFA_WORKFLOW.DFA_WORKFLOW_ID, 1
	FROM dfa.DFA_WORKFLOW_STATE DFA_WORKFLOW_STATE 
	JOIN dfa.DFA_WORKFLOW DFA_WORKFLOW ON DFA_WORKFLOW.SPAWN_DFA_WORKFLOW_ID = DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID
		and DFA_WORKFLOW.SPAWN_DFA_STATE_ID = DFA_WORKFLOW_STATE.DFA_STATE_ID
	WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = dfaWorkflowId AND DFA_WORKFLOW_STATE.IS_CURRENT = 1 AND DFA_WORKFLOW.SUB_STATE = 1;

	CALL dfa.sp_processValidConstraints(1000, NULL); 
   CALL demo_employee.sp_selectEmployeeWorkflows(0);
	
END GO
delimiter ;

grant EXECUTE ON PROCEDURE demo_employee.sp_findWorkflowAndCurrentSubWorkflows to demo_employee_user;

drop procedure if exists demo_employee.sp_processWorkflowEvent;
delimiter GO
create procedure demo_employee.sp_processWorkflowEvent(employeeId BIGINT UNSIGNED
	, dfaWorkflowId BIGINT UNSIGNED
	, eventTyp INT
	, commentTx MEDIUMTEXT
	, modBy VARCHAR(32)
	, raiseError BIT
	, refId INT /* 0 for interactive, 1 for system */
	, dfaStateId MEDIUMINT/* Optional - may be null */) 
	MODIFIES SQL DATA
BEGIN
	CALL demo_employee.initDfaFramework();
	CALL dfa.sp_processWorkflowEvent(dfaWorkflowId, eventTyp, commentTx, modBy, raiseError, refId, dfaStateId);
    -- Insert any newly created workflows.
	insert into EMPLOYEE_PROSPECT_WORKFLOW (EMPLOYEE_ID, DFA_WORKFLOW_ID, MOD_BY)
    select employeeId,sdwo.DFA_WORKFLOW_ID,modBy
    from dfa.session_dfa_workflow_out sdwo LEFT JOIN EMPLOYEE_PROSPECT_WORKFLOW epw ON epw.EMPLOYEE_ID = employeeId and epw.DFA_WORKFLOW_ID = sdwo.DFA_WORKFLOW_ID
    where OUTPUT=1 AND epw.EMPLOYEE_ID IS NULL;
END GO
delimiter ;

grant EXECUTE ON PROCEDURE demo_employee.sp_processWorkflowEvent to demo_employee_user;

DROP PROCEDURE IF EXISTS demo_employee.sp_startWorkflow;
delimiter GO
CREATE PROCEDURE demo_employee.sp_startWorkflow(employeeId BIGINT UNSIGNED, workflowTyp INT, commentTx MEDIUMTEXT, modBy VARCHAR(32), raiseError BIT, OUT dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA
BEGIN
	CALL demo_employee.initDfaFramework();
	CALL dfa.sp_do_startWorkflow(workflowTyp, commentTx, modBy, raiseError, 0, NULL, NULL, FALSE, dfaWorkflowId);

-- Insert the newly created employee record.
	insert into demo_employee.EMPLOYEE_PROSPECT_WORKFLOW (EMPLOYEE_ID, DFA_WORKFLOW_ID, MOD_BY)
    VALUES (employeeId, dfaWorkflowId, commentTx);

-- Also insert any other records created.
	insert into demo_employee.EMPLOYEE_PROSPECT_WORKFLOW (EMPLOYEE_ID, DFA_WORKFLOW_ID, MOD_BY)
    select employeeId,sdwo.DFA_WORKFLOW_ID,modBy
    from dfa.session_dfa_workflow_out sdwo LEFT JOIN EMPLOYEE_PROSPECT_WORKFLOW epw ON epw.EMPLOYEE_ID = employeeId and epw.DFA_WORKFLOW_ID = sdwo.DFA_WORKFLOW_ID
    where OUTPUT=1 AND epw.EMPLOYEE_ID IS NULL AND sdwo.DFA_WORKFLOW_ID <> dfaWorkflowId;
END GO
delimiter ;

grant EXECUTE ON PROCEDURE demo_employee.sp_startWorkflow to demo_employee_user;

drop procedure if exists demo_employee.sp_selectWorkflowEventsAndStates;
delimiter GO
create procedure demo_employee.sp_selectWorkflowEventsAndStates(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA	
BEGIN
	CALL dfa.sp_selectWorkflowEvents(dfaWorkflowId);
	CALL dfa.sp_selectWorkflowStates(dfaWorkflowId);
END GO
delimiter ;

grant EXECUTE ON PROCEDURE demo_employee.sp_selectWorkflowEventsAndStates to demo_employee_user;

flush PRIVILEGES;

