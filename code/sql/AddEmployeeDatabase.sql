/********************************************************
Create the 2 tables and stored procs for the add employee
demonstration program.

********************************************************/

use mysql;

drop database if exists demo_employee;

create database demo_employee;
use demo_employee;

delimiter GO
create procedure demo_employee.createUserAdminRoles() BEGIN
IF NOT EXISTS (select 1 from mysql.user where user = 'employeeweb') THEN
	create role demo_employee_user;
    create role demo_employee_admin;
	create user employeeweb identified by 'employeeweb';
    grant demo_employee_user to employeeweb;
    
    flush privileges;    
END IF;
END GO
delimiter ;

call demo_employee.createUserAdminRoles();

drop procedure demo_employee.createUserAdminRoles;

grant demo_employee_user to demo_employee_admin;
grant dfa_user to demo_employee_user;


CREATE TABLE LKUP_STATE (
state_id   smallint    unsigned not null auto_increment comment 'PK: Unique state ID',
state_name varchar(32) not null comment 'State name with first letter capital',
state_abbr char(2)  NOT NULL comment 'Optional state abbreviation (US is 2 capital letters)',
primary key (state_id),
index(state_abbr),
index(state_name)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Lookup table of US states.'
;

grant select ON LKUP_STATE to demo_employee_user;
grant update,delete,insert ON LKUP_STATE to demo_employee_admin;

insert into LKUP_STATE VALUES
(DEFAULT, 'Alabama', 'AL'),
(DEFAULT, 'Alaska', 'AK'),
(DEFAULT, 'Arizona', 'AZ'),
(DEFAULT, 'Arkansas', 'AR'),
(DEFAULT, 'California', 'CA'),
(DEFAULT, 'Colorado', 'CO'),
(DEFAULT, 'Connecticut', 'CT'),
(DEFAULT, 'Delaware', 'DE'),
(DEFAULT, 'District of Columbia', 'DC'),
(DEFAULT, 'Florida', 'FL'),
(DEFAULT, 'Georgia', 'GA'),
(DEFAULT, 'Hawaii', 'HI'),
(DEFAULT, 'Idaho', 'ID'),
(DEFAULT, 'Illinois', 'IL'),
(DEFAULT, 'Indiana', 'IN'),
(DEFAULT, 'Iowa', 'IA'),
(DEFAULT, 'Kansas', 'KS'),
(DEFAULT, 'Kentucky', 'KY'),
(DEFAULT, 'Louisiana', 'LA'),
(DEFAULT, 'Maine', 'ME'),
(DEFAULT, 'Maryland', 'MD'),
(DEFAULT, 'Massachusetts', 'MA'),
(DEFAULT, 'Michigan', 'MI'),
(DEFAULT, 'Minnesota', 'MN'),
(DEFAULT, 'Mississippi', 'MS'),
(DEFAULT, 'Missouri', 'MO'),
(DEFAULT, 'Montana', 'MT'),
(DEFAULT, 'Nebraska', 'NE'),
(DEFAULT, 'Nevada', 'NV'),
(DEFAULT, 'New Hampshire', 'NH'),
(DEFAULT, 'New Jersey', 'NJ'),
(DEFAULT, 'New Mexico', 'NM'),
(DEFAULT, 'New York', 'NY'),
(DEFAULT, 'North Carolina', 'NC'),
(DEFAULT, 'North Dakota', 'ND'),
(DEFAULT, 'Ohio', 'OH'),
(DEFAULT, 'Oklahoma', 'OK'),
(DEFAULT, 'Oregon', 'OR'),
(DEFAULT, 'Pennsylvania', 'PA'),
(DEFAULT, 'Rhode Island', 'RI'),
(DEFAULT, 'South Carolina', 'SC'),
(DEFAULT, 'South Dakota', 'SD'),
(DEFAULT, 'Tennessee', 'TN'),
(DEFAULT, 'Texas', 'TX'),
(DEFAULT, 'Utah', 'UT'),
(DEFAULT, 'Vermont', 'VT'),
(DEFAULT, 'Virginia', 'VA'),
(DEFAULT, 'Washington', 'WA'),
(DEFAULT, 'West Virginia', 'WV'),
(DEFAULT, 'Wisconsin', 'WI'),
(DEFAULT, 'Wyoming', 'WY')
;

CREATE TABLE EMPLOYEE_PROSPECT (
	EMPLOYEE_ID SERIAL PRIMARY KEY,
    LAST_NM VARCHAR(64) NOT NULL,
    FIRST_NM VARCHAR(64) NOT NULL,
	MIDDLE_NM VARCHAR(64) NULL,
    STREET_NM VARCHAR(64) NULL,
    CITY_NM VARCHAR(64) NULL,
    STATE_ID SMALLINT UNSIGNED NULL,
    PHONE_NUM VARCHAR(20) NULL,
    EMAIL_ADDR VARCHAR(64) NULL,
    SALARY NUMERIC(12,2) NULL,
    CONSTRAINT NEED_PHONE_OR_EMAIL CHECK (PHONE_NUM IS NOT NULL OR EMAIL_ADDR IS NOT NULL),
    CONSTRAINT FK_STATE FOREIGN KEY (STATE_ID) REFERENCES LKUP_STATE(STATE_ID),
    index(LAST_NM,FIRST_NM),
    index(FIRST_NM),
    index(STREET_NM),
    index(EMAIL_ADDR),
    index(PHONE_NUM)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Table of employee prospects (possible new employees).'
;

grant select,update,delete,insert ON EMPLOYEE_PROSPECT to demo_employee_user;

CREATE TABLE EMPLOYEE_PROSPECT_WORKFLOW (
	EMPLOYEE_ID BIGINT UNSIGNED NOT NULL,
    DFA_WORKFLOW_ID BIGINT UNSIGNED NOT NULL,
    MOD_BY VARCHAR(32),
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (EMPLOYEE_ID,DFA_WORKFLOW_ID),
    CONSTRAINT FK_EMPLOYEE_PROSPECT_WORKFLOW_EMPLOYEE FOREIGN KEY (EMPLOYEE_ID) REFERENCES EMPLOYEE_PROSPECT (EMPLOYEE_ID),
    CONSTRAINT FK_EMPLOYEE_PROSPECT_WORKFLOW_DFA_WORKFLOW FOREIGN KEY (DFA_WORKFLOW_ID) REFERENCES dfa.DFA_WORKFLOW (DFA_WORKFLOW_ID),
    UNIQUE (DFA_WORKFLOW_ID) -- Cardinality is 1 employee to many workflows.
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Binding table between employee prospects and the workflows.'
;

grant select,update,delete,insert ON EMPLOYEE_PROSPECT_WORKFLOW to demo_employee_user;

use dfa;

drop procedure if exists demo_employee.sp_findEmployeeWorkflows;
delimiter GO
create procedure demo_employee.sp_findEmployeeWorkflows(employeeId BIGINT UNSIGNED
	, workflowId BIGINT UNSIGNED
	, workflowTyp INT
   , likeLastNm VARCHAR(64)
   , likeFirstNm VARCHAR(64)
	, likeMiddleNm VARCHAR(64)
   , likeStreetNm VARCHAR(64)
   , likeCityNm VARCHAR(64)
   , stateId SMALLINT UNSIGNED
   , phoneNum VARCHAR(20)
   , likeEmailAddr VARCHAR(64)
   , active BIT
   , includeSubState BIT)
BEGIN
	IF (includeSubState IS NULL) THEN
		SET includeSubState = FALSE;
    END IF;

	CALL sp_cleanupSessionData();

	INSERT INTO session_dfa_workflow_state
	(DFA_WORKFLOW_ID, DFA_STATE_ID)
	SELECT epw.DFA_WORKFLOW_ID, 1 
	FROM demo_employee.EMPLOYEE_PROSPECT_WORKFLOW epw
	JOIN demo_employee.EMPLOYEE_PROSPECT EMPLOYEE_PROSPECT 
		ON EMPLOYEE_PROSPECT.EMPLOYEE_ID = epw.EMPLOYEE_ID
    -- Below left joins are to only bring in these tables if the corresponding
    -- search criteria are specified.
    LEFT JOIN DFA_WORKFLOW ON (workflowId IS NOT NULL OR includeSubState = TRUE) 
		AND DFA_WORKFLOW.DFA_WORKFLOW_ID = epw.WORKFLOW_ID
	LEFT JOIN DFA_WORKFLOW_STATE ON active IS NOT NULL 
		AND DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = epw.DFA_WORKFLOW_ID
		AND DFA_WORKFLOW_STATE.IS_CURRENT = 1
	LEFT JOIN dfa.LKUP_STATE LKUP_STATE ON active IS NOT NULL 
		AND LKUP_STATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP 
	WHERE (epw.DFA_WORKFLOW_ID = workflowId OR 
			(includeSubState AND DFA_WORKFLOW.SPAWN_DFA_WORKFLOW_ID = workflowId) 
		OR workflowId IS NULL)
	  AND (epw.EMPLOYEE_ID = employeeId OR employeeId IS NULL)
	  AND (EMPLOYEE_PROSPECT.LAST_NM like likeLastNm OR likeLastNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.FIRST_NM like likeFirstNm OR likeFirstNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.MIDDLE_NM like likeMiddleNm OR likeMiddleNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.STREET_NM like likeStreetNm OR likeStreetNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.CITY_NM like likeCityNm OR likeCityNm IS NULL)
	  AND (EMPLOYEE_PROSPECT.STATE_ID = stateId OR stateId IS NULL)
	  AND (EMPLOYEE_PROSPECT.PHONE_NUM like phoneNum OR phoneNum IS NULL)
	  AND (EMPLOYEE_PROSPECT.EMAIL_ADDR like likeEmailAddr OR likeEmailAddr IS NULL)
      AND (includeSubState OR DFA_WORKFLOW.SUB_STATE = FALSE)
      AND (workflowTyp IS NULL OR DFA_WORKFLOW.WORKFLOW_TYP = workflowTyp)
      AND (active IS NULL OR LKUP_STATE.ACTIVE = 1);

	CALL sp_processValidConstraints(2, NULL); 
    
    -- Bring back the data for the application.
    SELECT * FROM session_dfa_workflow_state sdws JOIN DFA_WORKFLOW ON sdws.DFA_WORKFLOW_ID = DFA_WORKFLOW.DFA_WORKFLOW_ID
    	join DFA_WORKFLOW_STATE ON DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = DFA_WORKFLOW.DFA_WORKFLOW_ID
    	JOIN LKUP_STATE ON LKUP_STATE.STATE_TYP = DFA_WORKFLOW_STATE.STATE_TYP
    	JOIN LKUP_EVENT ON LKUP_EVENT.EVENT_TYP = DFA_WORKFLOW_STATE.EVENT_TYP
    	JOIN LKUP_WORKFLOW_TYP ON LKUP_WORKFLOW_TYP.WORKFLOW_TYP;
		

END GO
delimiter ;

use demo_employee;

grant EXECUTE ON PROCEDURE demo_employee.sp_findEmployeeWorkflows to demo_employee_user;


drop procedure if exists demo_employee.sp_processWorkflowEvent;
delimiter GO
create procedure demo_employee.sp_processWorkflowEvent(employeeId BIGINT UNSIGNED
	, workflowId BIGINT UNSIGNED
	, eventTyp INT
	, commentTx MEDIUMTEXT
	, modBy VARCHAR(32)
	, raiseError BIT
	, refId INT /* 0 for interactive, 1 for system */
	, dfaStateId MEDIUMINT/* Optional - may be null */) 
	MODIFIES SQL DATA
BEGIN
	CALL dfa.sp_cleanupSessionData();
	CALL dfa.sp_processWorkflowEvent(workflowId, eventTyp, commentTx, modBy, raiseError, refId, dfaStateId);
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
CREATE PROCEDURE demo_employee.sp_startWorkflow(employeeId BIGINT UNSIGNED, workflowTyp INT, commentTx MEDIUMTEXT, modBy VARCHAR(32), raiseError BIT) 
	MODIFIES SQL DATA
BEGIN
	declare dfaWorkflowId BIGINT UNSIGNED DEFAULT NULL;
	CALL dfa.sp_cleanupSessionData();
	CALL dfa.sp_do_startWorkflow(workflowTyp, commentTx, modBy, raiseError, 0, NULL, NULL, FALSE, dfaWorkflowId);

-- Insert the newly created employee record.
	insert into EMPLOYEE_PROSPECT_WORKFLOW (EMPLOYEE_ID, DFA_WORKFLOW_ID, MOD_BY)
    VALUES (employeeId, dfaWorkflowId, commentTx);

-- Also insert any other records created.
	insert into EMPLOYEE_PROSPECT_WORKFLOW (EMPLOYEE_ID, DFA_WORKFLOW_ID, MOD_BY)
    select employeeId,sdwo.DFA_WORKFLOW_ID,modBy
    from dfa.session_dfa_workflow_out sdwo LEFT JOIN EMPLOYEE_PROSPECT_WORKFLOW epw ON epw.EMPLOYEE_ID = employeeId and epw.DFA_WORKFLOW_ID = sdwo.DFA_WORKFLOW_ID
    where OUTPUT=1 AND epw.EMPLOYEE_ID IS NULL AND sdwo.DFA_WORKFLOW_ID <> dfaWorkflowId;
END GO
delimiter ;

grant EXECUTE ON PROCEDURE demo_employee.sp_startWorkflow to demo_employee_user;

flush PRIVILEGES;

