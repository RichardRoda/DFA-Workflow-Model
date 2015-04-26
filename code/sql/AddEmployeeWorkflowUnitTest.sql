
use dfa;
set role dfa_user;

/******************************************************
Instructions:
This unit test returns multiple result sets.
A successful run returns a singleton of 'PASS' in each
result set.  A failed run has one or more rows with 
failures in one or more result sets.

Upon failure, it is necessary to manually run the 
ROLLBACK statement.
******************************************************/

START TRANSACTION;
-- This is where the application will insert the user's roles.
INSERT INTO `demo_employee`.`EMPLOYEE_PROSPECT`
(`LAST_NM`,
`FIRST_NM`,
`MIDDLE_NM`,
`STREET_NM`,
`CITY_NM`,
`STATE_ID`,
`PHONE_NUM`,
`EMAIL_ADDR`,
`POSITION`,
`SALARY`)
VALUES
('Person',
'Test',
'Tester',
'123 Unit Test Way',
'Test',
10,
'+11234567890',
'test.person@mytestway.com',
'Software Tester',
40000);

set @employeeId = last_insert_id();

CALL dfa.sp_cleanupSessionDataAndRoles();
insert into dfa.session_user_role (ROLE_NM) VALUES ('USER');
CALL demo_employee.sp_startWorkflow(@employeeId, 1000, 'Unit Test - Start Workflow', 'Employee UT', 1, @utDfaWorkflowId);

select CASE WHEN DFA_WORKFLOW.WORKFLOW_TYP = 1000 THEN 'PASS' ELSE '1 FAIL - Workflow Typ' END
	from DFA_WORKFLOW WHERE DFA_WORKFLOW.DFA_WORKFLOW_ID = @utDfaWorkflowId
union select CASE WHEN DFA_WORKFLOW_STATE.STATE_TYP = 1000 THEN 'PASS' ELSE '1 FAIL - State Typ' END
	from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
union select CASE WHEN DFA_WORKFLOW_STATE.EVENT_TYP = 1 THEN 'PASS' ELSE '1 FAIL - Event Typ' END
    from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
-- Expected for interactive: constraint id 1 of updatable.
UNION select CASE WHEN count(*) = 1 THEN 'PASS' 
	ELSE concat('1 Fail - expected 1 constraint got ', convert(count(*), char)) END
    from session_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId
UNION select CASE WHEN count(*) = 1 THEN 'PASS' 
	ELSE concat('1 Missing constraint type 1') END
    from session_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId and CONSTRAINT_ID=1
-- Expected for system: constraint id 1 and 2 of updatable.
UNION select CASE WHEN count(*) = 2 THEN 'PASS' 
	ELSE concat('1 Fail - expected 2 constraints got ', convert(count(*), char)) END
    from ref_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId AND REF_ID=1
UNION select CASE WHEN count(*) = 2 THEN 'PASS' 
	ELSE concat('1 Missing constraint type 1 or 2') END
    from ref_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId AND REF_ID=1 and CONSTRAINT_ID IN (1,2)
;

/*
dfa.sp_processWorkflowEvent(workflowId BIGINT UNSIGNED
	, eventTyp INT
	, commentTx MEDIUMTEXT
	, modBy VARCHAR(32)
	, raiseError BIT
	, refId INT  0 for interactive, 1 for system
	, dfaStateId MEDIUMINT Optional - may be null)
*/

CALL demo_employee.sp_processWorkflowEvent(@employeeId, @utDfaWorkflowId, 1000, 'Test expected event', 'Employee UT', 1, 0, 1);

select CASE WHEN DFA_WORKFLOW.WORKFLOW_TYP = 1000 THEN 'PASS' ELSE '2 FAIL - Workflow Typ' END
	from DFA_WORKFLOW WHERE DFA_WORKFLOW.DFA_WORKFLOW_ID = @utDfaWorkflowId
union select CASE WHEN DFA_WORKFLOW_STATE.STATE_TYP = 1003 THEN 'PASS' ELSE '2 FAIL - State Typ' END
	from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
union select CASE WHEN DFA_WORKFLOW_STATE.EVENT_TYP = 1000 THEN 'PASS' ELSE '2 FAIL - Event Typ' END
    from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
UNION select CASE WHEN count(*) = 1 THEN 'PASS'
	ELSE concat('2 Fail - expected 1 current state, got ', convert(count(*), char)) END
    from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
-- Expected for interactive: constraint id 1 of updatable.
UNION select CASE WHEN count(*) = 2 THEN 'PASS' 
	ELSE concat('2 Fail - expected 1 constraint got ', convert(count(*), char)) END
    from session_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId
UNION select CASE WHEN count(*) = 2 THEN 'PASS' 
	ELSE concat('2 Missing constraint type 1') END
    from session_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId and CONSTRAINT_ID IN (1,3)
-- Expected for system: constraint id 1 and 2 of updatable.
UNION select CASE WHEN count(*) = 3 THEN 'PASS' 
	ELSE concat('2 Fail - expected 2 constraints got ', convert(count(*), char)) END
    from ref_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId AND REF_ID=1
UNION select CASE WHEN count(*) = 3 THEN 'PASS' 
	ELSE concat('2 Missing constraint type 1, 2, or 3') END
    from ref_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId AND REF_ID=1 and CONSTRAINT_ID IN (1,2,3)
;

CALL demo_employee.sp_processWorkflowEvent(@employeeId, @utDfaWorkflowId, 1003, 'Test expected event', 'Employee UT', 1, 0, 2);

select CASE WHEN DFA_WORKFLOW.WORKFLOW_TYP = 1000 THEN 'PASS' ELSE '3 FAIL - Workflow Typ' END
	from DFA_WORKFLOW WHERE DFA_WORKFLOW.DFA_WORKFLOW_ID = @utDfaWorkflowId
union select CASE WHEN DFA_WORKFLOW_STATE.STATE_TYP = 1004 THEN 'PASS' ELSE '3 FAIL - State Typ' END
	from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
union select CASE WHEN DFA_WORKFLOW_STATE.EVENT_TYP = 1003 THEN 'PASS' ELSE '3 FAIL - Event Typ' END
    from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
UNION select CASE WHEN count(*) = 1 THEN 'PASS'
	ELSE concat('3 Fail - expected 1 current state, got ', convert(count(*), char)) END
    from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
-- Expected for interactive: constraint id 1 of updatable.
UNION select CASE WHEN count(*) = 2 THEN 'PASS' 
	ELSE concat('3 Fail - expected 1 constraint got ', convert(count(*), char)) END
    from session_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId
UNION select CASE WHEN count(*) = 2 THEN 'PASS' 
	ELSE concat('3 Missing constraint type 1') END
    from session_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId and CONSTRAINT_ID IN (1,3)
-- Expected for system: constraint id 1 and 2 of updatable.
UNION select CASE WHEN count(*) = 3 THEN 'PASS' 
	ELSE concat('3 Fail - expected 2 constraints got ', convert(count(*), char)) END
    from ref_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId AND REF_ID=1
UNION select CASE WHEN count(*) = 3 THEN 'PASS' 
	ELSE concat('3 Missing constraint type 1, 2, or 3') END
    from ref_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId AND REF_ID=1 and CONSTRAINT_ID IN (1,2,3)
;

CALL demo_employee.sp_findEmployeeWorkflows(@employeeId, @utDfaWorkflowId, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
CALL demo_employee.sp_selectWorkflowEventsAndStates(@utDfaWorkflowId);

CALL demo_employee.sp_processWorkflowEvent(@employeeId, @utDfaWorkflowId, 1005, 'Test expected event', 'Employee UT', 1, 0, 3);

select CASE WHEN DFA_WORKFLOW.WORKFLOW_TYP = 1000 THEN 'PASS' ELSE '4 FAIL - Workflow Typ' END
	from DFA_WORKFLOW WHERE DFA_WORKFLOW.DFA_WORKFLOW_ID = @utDfaWorkflowId
union select CASE WHEN DFA_WORKFLOW_STATE.STATE_TYP = 1002 THEN 'PASS' ELSE '4 FAIL - State Typ' END
	from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
union select CASE WHEN DFA_WORKFLOW_STATE.EVENT_TYP = 1005 THEN 'PASS' ELSE '4 FAIL - Event Typ ' END
    from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
UNION select CASE WHEN count(*) = 1 THEN 'PASS'
	ELSE concat('4 Fail - expected 1 current state, got ', convert(count(*), char)) END
    from DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = @utDfaWorkflowId 
    AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
-- Expected for interactive: constraint id 1 of updatable.
UNION select CASE WHEN count(*) = 2 THEN 'PASS' 
	ELSE concat('4 Fail - expected 1 constraint got ', convert(count(*), char)) END
    from session_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId
UNION select CASE WHEN count(*) = 2 THEN 'PASS' 
	ELSE concat('4 Missing constraint type 1') END
    from session_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId and CONSTRAINT_ID IN (1,3)
-- Expected for system: constraint id 1 and 2 of updatable.
UNION select CASE WHEN count(*) = 3 THEN 'PASS' 
	ELSE concat('4 Fail - expected 2 constraints got ', convert(count(*), char)) END
    from ref_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId AND REF_ID=1
UNION select CASE WHEN count(*) = 3 THEN 'PASS' 
	ELSE concat('4 Missing constraint type 1, 2, or 3') END
    from ref_dfa_constraint WHERE DFA_WORKFLOW_ID = @utDfaWorkflowId AND REF_ID=1 and CONSTRAINT_ID IN (1,2,3)
;

CALL demo_employee.sp_findWorkflowAndCurrentSubWorkflows(@utDfaWorkflowId);
CALL dfa.sp_selectWorkflowEvents(@utDfaWorkflowId);

ROLLBACK;
