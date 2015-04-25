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
    POSITION VARCHAR(32) NULL,
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

flush PRIVILEGES;

