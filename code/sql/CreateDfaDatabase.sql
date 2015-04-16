
/******************************************************************************
MySql file to create the basic DFA workflow schema.  This file should only
be run for initial create as it erases (drops) the dfa database before
re-creating it again.

Note: In MySql, the length specified for the int is a display width for
a result set, and has no effect on the range of the datatype.
******************************************************************************/

drop database dfa;
create database dfa;
use dfa;

/*********************************************************************
These lookup tables are frequently accessed but infrequently modified.
Therefore, liberally create indices for them.
*********************************************************************/

-- Use stored proc to conditionally create these roles.
delimiter GO
create procedure dfa.createUserAdminRoles() BEGIN
IF NOT EXISTS (select 1 from mysql.user where user = 'dfa_user') THEN
	create role dfa_viewer;
	create role dfa_user;
	create role dfa_admin;
END IF;
END GO
delimiter ;

call dfa.createUserAdminRoles();

drop procedure dfa.createUserAdminRoles;

-- dfa_admin automatically gets any dfa_user privilidges.
grant dfa_viewer to dfa_user;
grant dfa_user to dfa_admin;

CREATE TABLE LKUP_CONSTRAINT
	(
	CONSTRAINT_ID   INT NOT NULL PRIMARY KEY,
	DESCRIPTION_TX    VARCHAR (128) NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	DEVELOPER_DESC_TX VARCHAR (128) NULL
	)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='A constraint represents a set of facts about the user and the data being operated on.  Constraints are satisfied when all of the facts on the data being operated on are true, and all of the facts about the user are true.  Satisfaction may be expressed at three different levels: show, updatable, and responsible.  Show and updatable are self-explanatory,  Responsible implies updatable and means that the current logged in user is responsible for execution.  Applies primarily to the expected next event.';
grant select on LKUP_CONSTRAINT to dfa_viewer;
grant insert,update,delete on LKUP_CONSTRAINT to dfa_admin;

-- Insert 3 common types for applications.
-- Note: Non-use of constraint 0 is enforced using 
-- table level constraints on LKUP_CONSTRAINT_APP and tmp_dfa_constraint.
INSERT INTO LKUP_CONSTRAINT
(CONSTRAINT_ID,DESCRIPTION_TX,DEVELOPER_DESC_TX,MOD_BY) VALUES
(0,'Nobody / Disabled / Deleted', 'Constraint ID that will never match a user or entity.  Use this to implement a soft delete.', 'Test');

INSERT INTO LKUP_CONSTRAINT
(CONSTRAINT_ID,DESCRIPTION_TX,DEVELOPER_DESC_TX,MOD_BY) VALUES
(1,'Anyone', 'Lowest common denominator constraint for application access to an entity.', 'Test');

INSERT INTO LKUP_CONSTRAINT
(CONSTRAINT_ID,DESCRIPTION_TX,DEVELOPER_DESC_TX,MOD_BY) VALUES
(2,'System Only', 'Constraint that represents something only the system can access or do.', 'Test');

INSERT INTO LKUP_CONSTRAINT
(CONSTRAINT_ID,DESCRIPTION_TX,DEVELOPER_DESC_TX,MOD_BY) VALUES
(3,'Undoable', 'Constraint that represents a workflow that is undoable by anyone.', 'Test');

CREATE TABLE LKUP_APPLICATION (
	APPLICATION_ID INT NOT NULL PRIMARY KEY,
	APPLICATION_NM VARCHAR(21) NOT NULL,
	APPLICATION_DESC VARCHAR(128) NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	INDEX (APPLICATION_NM)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Applications that use the DFA model.  This model allows for applications to share workflows.  The DFA constraints are defined such that each application may specify their fields and roles independently.';

grant select on LKUP_APPLICATION to dfa_viewer;
grant insert,update,delete on LKUP_APPLICATION to dfa_admin;

INSERT INTO LKUP_APPLICATION
	(APPLICATION_ID, APPLICATION_NM, APPLICATION_DESC, MOD_BY)
	VALUES (1, 'DFA', 'Dfa Common Application', 'DFA Admin');

INSERT INTO LKUP_APPLICATION
	(APPLICATION_ID, APPLICATION_NM, APPLICATION_DESC, MOD_BY)
	VALUES (2, 'Demo', 'DFA Demo', 'DFA Admin');

CREATE TABLE LKUP_CONSTRAINT_APP (
	APPLICATION_ID INT NOT NULL,
	CONSTRAINT_ID  INT NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FIELD_COUNT SMALLINT UNSIGNED DEFAULT 0 NOT NULL,
	ROLE_COUNT SMALLINT UNSIGNED DEFAULT 0 NOT NULL,
	PRIMARY KEY (APPLICATION_ID,CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (APPLICATION_ID) REFERENCES LKUP_APPLICATION (APPLICATION_ID),
	CONSTRAINT FOREIGN KEY (CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT (CONSTRAINT_ID),
    CONSTRAINT NO_CONSTRAINT_0 CHECK (CONSTRAINT_ID <> 0),
    INDEX (FIELD_COUNT),
    INDEX (ROLE_COUNT)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Associates a constraint with an application.  This schema is designed to allow sharing of workflow types amoung applications.  This allows differing applications to define the meaning of specified constraints as defined by their requirements.  FIELD_COUNT is trigger managed and is a count of the fields related to this constraint.';

grant select on LKUP_CONSTRAINT_APP to dfa_user;
grant insert(APPLICATION_ID,CONSTRAINT_ID,MOD_BY,MOD_DT),update(APPLICATION_ID,CONSTRAINT_ID,MOD_BY,MOD_DT),delete on LKUP_CONSTRAINT_APP to dfa_admin;

INSERT INTO dfa.LKUP_CONSTRAINT_APP
(APPLICATION_ID,CONSTRAINT_ID,MOD_BY)
 VALUES (1,3,'DFA Admin');

INSERT INTO dfa.LKUP_CONSTRAINT_APP
(APPLICATION_ID,CONSTRAINT_ID,MOD_BY)
 VALUES (1,2,'DFA Admin');

CREATE TABLE LKUP_CONSTRAINT_APP_ROLE
	(
	APPLICATION_ID INT NOT NULL,
	CONSTRAINT_ID INT NOT NULL,
	ROLE_NM         VARCHAR (16) NOT NULL,
	IS_SHOW            BIT DEFAULT true NOT NULL,
	ALLOW_UPDATE    BIT DEFAULT true NOT NULL,
	IS_RESPONSIBLE     BIT DEFAULT false NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID,CONSTRAINT_ID,ROLE_NM),
	CONSTRAINT MUST_ALLOW_ONE CHECK  (IS_SHOW <> 0 OR ALLOW_UPDATE <> 0 OR IS_RESPONSIBLE <> 0),
	CONSTRAINT FK_LKUP_CONSTRAINT_APP FOREIGN KEY (APPLICATION_ID,CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT_APP (APPLICATION_ID,CONSTRAINT_ID),
	INDEX (IS_SHOW),
	INDEX (ALLOW_UPDATE),
	INDEX (IS_RESPONSIBLE)
	)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Defines how the user roles satisfies constraints.  Show is satisfied if the user has at least 1 role that matches with IS_SHOW of true.  Update is satisfied if show is satisfied and the user has at least 1 role that matches with ALLOW_UPDATE of true (may be different than the role which satisfied Show).  Responsible is satisfied if update is satisfied and the user has at least 1 role that matches with IS_RESPONSIBLE of true.  Currently, responsible only has an effect on a states expected next event transition.';

grant select on LKUP_CONSTRAINT_APP_ROLE to dfa_user;
grant insert,update,delete on LKUP_CONSTRAINT_APP_ROLE to dfa_admin;

-- Automatically manage the constraint count.
delimiter GO
CREATE TRIGGER LKUP_CONSTRAINT_APP_ROLE_AFTER_INSERT AFTER INSERT ON LKUP_CONSTRAINT_APP_ROLE 
FOR EACH ROW 
BEGIN
	update LKUP_CONSTRAINT_APP SET ROLE_COUNT = ROLE_COUNT + 1 WHERE LKUP_CONSTRAINT_APP.APPLICATION_ID = NEW.APPLICATION_ID
		AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID = NEW.CONSTRAINT_ID;
END GO
delimiter ;

delimiter GO
CREATE TRIGGER LKUP_CONSTRAINT_APP_ROLE_AFTER_DELETE AFTER DELETE ON LKUP_CONSTRAINT_APP_ROLE 
FOR EACH ROW 
BEGIN
	update LKUP_CONSTRAINT_APP SET ROLE_COUNT = ROLE_COUNT - 1 WHERE LKUP_CONSTRAINT_APP.APPLICATION_ID = OLD.APPLICATION_ID
		AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID = OLD.CONSTRAINT_ID;
END GO
delimiter ;

delimiter GO
CREATE TRIGGER LKUP_CONSTRAINT_APP_ROLE_AFTER_UPDATE AFTER UPDATE ON LKUP_CONSTRAINT_APP_ROLE 
FOR EACH ROW 
BEGIN
	IF (NEW.APPLICATION_ID <> OLD.APPLICATION_ID OR NEW.CONSTRAINT_ID <> OLD.CONSTRAINT_ID) THEN
		update LKUP_CONSTRAINT_APP SET ROLE_COUNT = ROLE_COUNT + 1 WHERE LKUP_CONSTRAINT_APP.APPLICATION_ID = NEW.APPLICATION_ID
			AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID = NEW.CONSTRAINT_ID;
		update LKUP_CONSTRAINT_APP SET ROLE_COUNT = ROLE_COUNT - 1 WHERE LKUP_CONSTRAINT_APP.APPLICATION_ID = OLD.APPLICATION_ID
			AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID = OLD.CONSTRAINT_ID;
	END IF;
END GO
delimiter ;

INSERT INTO `dfa`.`LKUP_CONSTRAINT_APP_ROLE`
(`APPLICATION_ID`,`ROLE_NM`,`CONSTRAINT_ID`,`MOD_BY`) VALUES (1,'SYSTEM',2,'DFA Admin');

CREATE TABLE LKUP_ENTITY (
	ENTITY_ID INT NOT NULL PRIMARY KEY,
	ENTITY_TX VARCHAR(60) NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP	
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Defines a common logical entity from which fields may be accessed.  Although this may be a database table, it may also be a subset (view-like) of a table.  An example of such a subset would be specifying a current and future position as entities even though they are both contained in a common employee position table.';

grant select on LKUP_ENTITY to dfa_viewer;
grant insert,update,delete on LKUP_ENTITY to dfa_admin;

insert into LKUP_ENTITY (ENTITY_ID,ENTITY_TX,MOD_BY) VALUES (1,'DFA_WORKFLOW_STATE', 'DFA Admin');

CREATE TABLE LKUP_FIELD_TYP (
	FIELD_TYP_ID SMALLINT NOT NULL PRIMARY KEY,
	FIELD_TYP_TX VARCHAR(60) NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP	
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Specifies the type of the field.  This impacts which column the field data is stored on the session table, which table specifies values which satisfy the field, and is a hint to the view layer on how to display the field.';

grant select on LKUP_FIELD_TYP to dfa_viewer;
grant insert,update,delete on LKUP_FIELD_TYP to dfa_admin;

insert into LKUP_FIELD_TYP (FIELD_TYP_ID,FIELD_TYP_TX,MOD_BY)
VALUES (1,'Integer','DFA ADMIN');

insert into LKUP_FIELD_TYP (FIELD_TYP_ID,FIELD_TYP_TX,MOD_BY)
VALUES (2,'Bit','DFA ADMIN');

insert into LKUP_FIELD_TYP (FIELD_TYP_ID,FIELD_TYP_TX,MOD_BY)
VALUES (3,'Date','DFA ADMIN');

insert into LKUP_FIELD_TYP (FIELD_TYP_ID,FIELD_TYP_TX,MOD_BY)
VALUES (4,'String','DFA ADMIN');

CREATE TABLE LKUP_FIELD (
	FIELD_ID INT NOT NULL PRIMARY KEY,
	FIELD_TYP_ID SMALLINT NOT NULL,
	ENTITY_ID INT NOT NULL,
	FIELD_TX VARCHAR(60) NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT FOREIGN KEY (FIELD_TYP_ID) REFERENCES LKUP_FIELD_TYP (FIELD_TYP_ID),
	CONSTRAINT FOREIGN KEY (ENTITY_ID) REFERENCES LKUP_ENTITY (ENTITY_ID)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Specified a logical field (not necessiarly a database table.field).  The logical entity and type of the field are expressed by the FIELD_TYP_ID and ENTITY_ID relationships.  FIELD_TX identifies the field.  Some creativity with the field definitions enables certain kinds of constraints.  Examples are: number of days difference between today and a date as an integer enables N-day past/present/future constraints.  Bit fields (with an appropriate entity type) may be used as a means to record satisfaction/non-satisfaction of arbitrary facts.';

grant select on LKUP_FIELD to dfa_viewer;
grant insert,update,delete on LKUP_FIELD to dfa_admin;

INSERT INTO `dfa`.`LKUP_FIELD`
(`FIELD_ID`,`FIELD_TYP_ID`,`ENTITY_ID`,`FIELD_TX`,`MOD_BY`)
VALUES
(1,2,1,'DFA Undoable','DFA Admin');


CREATE TABLE LKUP_CONSTRAINT_APP_FIELD (
	APPLICATION_ID INT NOT NULL,
	FIELD_ID       INT NOT NULL,
	CONSTRAINT_ID  INT NOT NULL,
	NULL_VALID BIT DEFAULT false, 
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (APPLICATION_ID,CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT_APP (APPLICATION_ID,CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (FIELD_ID) REFERENCES LKUP_FIELD (FIELD_ID),
	INDEX (NULL_VALID)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Specifies that satisfaction of a given constraint for a given application depends on the value of the specified logical field.  When the field value is missing or null, satisfaction of the constraint is controlled by the NULL_VALID property.  Otherwise, range or other specifier tables are used according to the FIELD_TYP_ID of the related field.  It is permissible specify that a value must be null or missing by inserting this row and omitting specifier inserts for the field type.';

grant select on LKUP_CONSTRAINT_APP_FIELD to dfa_user;
grant insert,update,delete on LKUP_CONSTRAINT_APP_FIELD to dfa_admin;

-- Automatically manage the constraint count.
delimiter GO
CREATE TRIGGER LKUP_CONSTRAINT_APP_FIELD_AFTER_INSERT AFTER INSERT ON LKUP_CONSTRAINT_APP_FIELD 
FOR EACH ROW 
BEGIN
	update LKUP_CONSTRAINT_APP SET ROLE_COUNT = FIELD_COUNT + 1 WHERE LKUP_CONSTRAINT_APP.APPLICATION_ID = NEW.APPLICATION_ID
		AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID = NEW.CONSTRAINT_ID;
END GO
delimiter ;

delimiter GO
CREATE TRIGGER LKUP_CONSTRAINT_APP_FIELD_AFTER_DELETE AFTER DELETE ON LKUP_CONSTRAINT_APP_FIELD 
FOR EACH ROW 
BEGIN
	update LKUP_CONSTRAINT_APP SET FIELD_COUNT = FIELD_COUNT - 1 WHERE LKUP_CONSTRAINT_APP.APPLICATION_ID = OLD.APPLICATION_ID
		AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID = OLD.CONSTRAINT_ID;
END GO
delimiter ;

delimiter GO
CREATE TRIGGER LKUP_CONSTRAINT_APP_FIELD_AFTER_UPDATE AFTER UPDATE ON LKUP_CONSTRAINT_APP_FIELD 
FOR EACH ROW 
BEGIN
	IF (NEW.APPLICATION_ID <> OLD.APPLICATION_ID OR NEW.CONSTRAINT_ID <> OLD.CONSTRAINT_ID) THEN
		update LKUP_CONSTRAINT_APP SET FIELD_COUNT = FIELD_COUNT + 1 WHERE LKUP_CONSTRAINT_APP.APPLICATION_ID = NEW.APPLICATION_ID
			AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID = NEW.CONSTRAINT_ID;
		update LKUP_CONSTRAINT_APP SET FIELD_COUNT = FIELD_COUNT - 1 WHERE LKUP_CONSTRAINT_APP.APPLICATION_ID = OLD.APPLICATION_ID
			AND LKUP_CONSTRAINT_APP.CONSTRAINT_ID = OLD.CONSTRAINT_ID;
	END IF;
END GO
delimiter ;

INSERT INTO `dfa`.`LKUP_CONSTRAINT_APP_FIELD`
(`APPLICATION_ID`,
`FIELD_ID`,
`CONSTRAINT_ID`,
`MOD_BY`)
VALUES
(1,1,3,'DFA Admin');


/*
INSERT INTO LKUP_ENTITY
	(ENTITY_ID, ENTITY_TX, MOD_BY)
	VALUES (1, 'Test', 'Test');

INSERT INTO LKUP_FIELD
	(FIELD_ID, ENTITY_ID, FIELD_TX, MOD_BY)
	VALUES (1, 1, 'Field1', 'Test');

INSERT INTO LKUP_FIELD
	(FIELD_ID, ENTITY_ID, FIELD_TX, MOD_BY)
	VALUES (2, 1, 'Field2', 'Test');

INSERT INTO LKUP_FIELD
	(FIELD_ID, ENTITY_ID, FIELD_TX, MOD_BY)
	VALUES (3, 1, 'Field3', 'Test');

INSERT INTO LKUP_CONSTRAINT
	(CONSTRAINT_ID, DESCRIPTION_TX, MOD_BY)
	VALUES (1, 'Test', 'Test');
	
INSERT INTO LKUP_CONSTRAINT_APP
	(APPLICATION_ID, CONSTRAINT_ID, MOD_BY)
	VALUES (1, 1, 'Test');
	
select 0 as expected, field_count as actual from LKUP_CONSTRAINT_APP where application_id = 1 and constraint_id = 1;

INSERT INTO LKUP_CONSTRAINT_APP_FIELD
	(APPLICATION_ID, FIELD_ID, CONSTRAINT_ID, MOD_BY)
	VALUES (1, 1, 1, 'Test');

select 1 as expected, field_count as actual from LKUP_CONSTRAINT_APP where application_id = 1 and constraint_id = 1;

INSERT INTO LKUP_CONSTRAINT_APP_FIELD
	(APPLICATION_ID, FIELD_ID, CONSTRAINT_ID, MOD_BY)
	VALUES (1, 2, 1, 'Test');

select 2 as expected, field_count as actual from LKUP_CONSTRAINT_APP where application_id = 1 and constraint_id = 1;

INSERT INTO LKUP_CONSTRAINT_APP_FIELD
	(APPLICATION_ID, FIELD_ID, CONSTRAINT_ID, MOD_BY)
	VALUES (1, 3, 1, 'Test');

select 3 as expected, field_count as actual from LKUP_CONSTRAINT_APP where application_id = 1 and constraint_id = 1;

delete from LKUP_CONSTRAINT_APP_FIELD where CONSTRAINT_ID = 1 and FIELD_ID IN (2,3);

select 1 as expected, field_count as actual from LKUP_CONSTRAINT_APP where application_id = 1 and constraint_id = 1;
*/

-- No overlaps, trigger enforced.
CREATE TABLE LKUP_CONSTRAINT_FIELD_INT_RANGE (
	APPLICATION_ID INT NOT NULL,
	FIELD_ID INT NOT NULL,
	CONSTRAINT_ID INT NOT NULL,
	SMALLEST_VALUE BIGINT NOT NULL DEFAULT -9223372036854775808,
	LARGEST_VALUE BIGINT NOT NULL DEFAULT 9223372036854775807,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID, SMALLEST_VALUE),
	CONSTRAINT FOREIGN KEY (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT_APP_FIELD (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID),
	CONSTRAINT CHECK (SMALLEST_VALUE <= LARGEST_VALUE),
	INDEX (LARGEST_VALUE)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Defines an integer range for a constraint suitable for use with TINYINT (UNSIGNED), SMALLINT (UNSIGNED), MEDIUMINT (UNSIGNED), INT (UNSIGNED), BIGINT and BIGINT UNSIGNED if values are <= 9223372036854775807.  A trigger gurantees that no two ranges overlap so they may be used directly without fear of a duplicate row.  Omitting either smallest or largest value causes the minimum or maximum to be used as the value.  Ommitting both is a way to specify that any value is valid.  A specific value is specified by setting both largest and smallest to it.';

grant select on LKUP_CONSTRAINT_FIELD_INT_RANGE to dfa_user;
grant insert,update,delete on LKUP_CONSTRAINT_FIELD_INT_RANGE to dfa_admin;

-- Enforce no overlaps.
delimiter GO
create trigger LKUP_CONSTRAINT_FIELD_INT_RANGE_BEFORE_INSERT before insert on LKUP_CONSTRAINT_FIELD_INT_RANGE
for each row
begin
	DECLARE ERROR_TX VARCHAR(128);
	if exists (select * from LKUP_CONSTRAINT_FIELD_INT_RANGE lcfir where lcfir.APPLICATION_ID = NEW.APPLICATION_ID and lcfir.FIELD_ID = NEW.FIELD_ID and lcfir.CONSTRAINT_ID = NEW.CONSTRAINT_ID
		AND lcfir.SMALLEST_VALUE <= NEW.LARGEST_VALUE and NEW.SMALLEST_VALUE <= lcfir.LARGEST_VALUE LIMIT 1) THEN		
		select CONCAT('Range overlaps with ', convert(lcfir.SMALLEST_VALUE, char), '-', convert(lcfir.LARGEST_VALUE, char)) INTO ERROR_TX from LKUP_CONSTRAINT_FIELD_INT_RANGE lcfir
		where lcfir.APPLICATION_ID = NEW.APPLICATION_ID and lcfir.FIELD_ID = NEW.FIELD_ID and lcfir.CONSTRAINT_ID = NEW.CONSTRAINT_ID
			AND lcfir.SMALLEST_VALUE <= NEW.LARGEST_VALUE and NEW.SMALLEST_VALUE <= lcfir.LARGEST_VALUE LIMIT 1;
		SIGNAL SQLSTATE '45000' SET message_text=ERROR_TX;
	END IF;
end GO
delimiter ; 

delimiter GO
create trigger LKUP_CONSTRAINT_FIELD_INT_RANGE_AFTER_UPDATE after update on LKUP_CONSTRAINT_FIELD_INT_RANGE
for each row
begin
	DECLARE ERROR_TX VARCHAR(128);
	if exists (select * from LKUP_CONSTRAINT_FIELD_INT_RANGE lcfir where lcfir.APPLICATION_ID = NEW.APPLICATION_ID and lcfir.FIELD_ID = NEW.FIELD_ID and lcfir.CONSTRAINT_ID = NEW.CONSTRAINT_ID AND NEW.SMALLEST_VALUE <> lcfir.SMALLEST_VALUE
		AND lcfir.SMALLEST_VALUE <= NEW.LARGEST_VALUE and NEW.SMALLEST_VALUE <= lcfir.LARGEST_VALUE LIMIT 1) THEN		
		select CONCAT('Range overlaps with ', convert(lcfir.SMALLEST_VALUE, char), '-', convert(lcfir.LARGEST_VALUE, char)) INTO ERROR_TX from LKUP_CONSTRAINT_FIELD_INT_RANGE lcfir
		where lcfir.APPLICATION_ID = NEW.APPLICATION_ID and lcfir.FIELD_ID = NEW.FIELD_ID and lcfir.CONSTRAINT_ID = NEW.CONSTRAINT_ID  AND NEW.SMALLEST_VALUE <> lcfir.SMALLEST_VALUE
			AND lcfir.SMALLEST_VALUE <= NEW.LARGEST_VALUE and NEW.SMALLEST_VALUE <= lcfir.LARGEST_VALUE LIMIT 1;
		SIGNAL SQLSTATE '45000' SET message_text=ERROR_TX;
	END IF;
end GO
delimiter ; 

/*
insert into LKUP_ENTITY (ENTITY_ID, ENTITY_TX, MOD_BY) VALUES (1, 'Test Entity', 'DFA ADMIN');
insert into LKUP_FIELD (FIELD_ID, ENTITY_ID, FIELD_TX, MOD_BY) VALUES (1,1,'Test Field', 'DFA ADMIN');
insert into LKUP_CONSTRAINT (CONSTRAINT_ID,DESCRIPTION_TX,MOD_BY) VALUES (1,'TEST CONSTRAINT','UNIT TEST');
insert into LKUP_CONSTRAINT_APP (APPLICATION_ID, CONSTRAINT_ID, MOD_BY) VALUES (1,1,'UNIT TEST');
insert into LKUP_CONSTRAINT_APP_FIELD (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID, MOD_BY) VALUES (1,1,1,'UNIT TEST');

insert into LKUP_CONSTRAINT_FIELD_INT_RANGE (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID,SMALLEST_VALUE,LARGEST_VALUE,MOD_BY)
VALUES (1,1,1,0,1000,'TEST');
insert into LKUP_CONSTRAINT_FIELD_INT_RANGE (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID,SMALLEST_VALUE,LARGEST_VALUE,MOD_BY)
VALUES (1,1,1,2000,3000,'TEST'); -- Should PASS
insert into LKUP_CONSTRAINT_FIELD_INT_RANGE (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID,SMALLEST_VALUE,LARGEST_VALUE,MOD_BY)
VALUES (1,1,1,1000,3000,'TEST'); -- Should FAIL
insert into LKUP_CONSTRAINT_FIELD_INT_RANGE (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID,SMALLEST_VALUE,LARGEST_VALUE,MOD_BY)
VALUES (1,1,1,1500,3500,'TEST'); -- Should FAIL (contains 2000-3000)
insert into LKUP_CONSTRAINT_FIELD_INT_RANGE (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID,SMALLEST_VALUE,LARGEST_VALUE,MOD_BY)
VALUES (1,1,1,2250,2750,'TEST'); -- Should FAIL (contained by 2000-3000)

-- Should PASS:
update LKUP_CONSTRAINT_FIELD_INT_RANGE SET LARGEST_VALUE = 900 WHERE APPLICATION_ID=1 and FIELD_ID=1 AND CONSTRAINT_ID=1 AND SMALLEST_VALUE=0

-- Should FAIL:
update LKUP_CONSTRAINT_FIELD_INT_RANGE SET LARGEST_VALUE = 2000 WHERE APPLICATION_ID=1 and FIELD_ID=1 AND CONSTRAINT_ID=1 AND SMALLEST_VALUE=0
*/

-- No overlaps, trigger enforced.
-- This is useful for rules that depend on specific dates.
CREATE TABLE LKUP_CONSTRAINT_FIELD_DATE_RANGE (
	APPLICATION_ID INT NOT NULL,
	FIELD_ID INT NOT NULL,
	CONSTRAINT_ID INT NOT NULL,
	SMALLEST_VALUE DATE NOT NULL DEFAULT '1000-01-01',
	LARGEST_VALUE DATE NOT NULL DEFAULT '9999-12-31',
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID, SMALLEST_VALUE),
	CONSTRAINT FOREIGN KEY (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT_APP_FIELD (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID),
	CONSTRAINT CHECK (SMALLEST_VALUE <= LARGEST_VALUE),
	INDEX (LARGEST_VALUE)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Defines an date range for a constraint.  A trigger gurantees that no two ranges overlap so they may be used directly without fear of a duplicate row.  Omitting either smallest or largest value causes the minimum or maximum to be used as the value.  Ommitting both is a way to specify that any value is valid.  A specific value is specified by setting both largest and smallest to it.';


grant select on LKUP_CONSTRAINT_FIELD_DATE_RANGE to dfa_user;
grant insert,update,delete on LKUP_CONSTRAINT_FIELD_DATE_RANGE to dfa_admin;


-- Enforce no overlaps.
delimiter GO
create trigger LKUP_CONSTRAINT_FIELD_DATE_RANGE_BEFORE_INSERT before insert on LKUP_CONSTRAINT_FIELD_DATE_RANGE
for each row
begin
	DECLARE ERROR_TX VARCHAR(128);
	if exists (select * from LKUP_CONSTRAINT_FIELD_INT_RANGE lcfir where lcfir.APPLICATION_ID = NEW.APPLICATION_ID and lcfir.FIELD_ID = NEW.FIELD_ID and lcfir.CONSTRAINT_ID = NEW.CONSTRAINT_ID
		AND lcfir.SMALLEST_VALUE <= NEW.LARGEST_VALUE and NEW.SMALLEST_VALUE <= lcfir.LARGEST_VALUE LIMIT 1) THEN		
		select CONCAT('Range overlaps with ', convert(lcfir.SMALLEST_VALUE, char), '-', convert(lcfir.LARGEST_VALUE, char)) INTO ERROR_TX from LKUP_CONSTRAINT_FIELD_INT_RANGE lcfir
		where lcfir.APPLICATION_ID = NEW.APPLICATION_ID and lcfir.FIELD_ID = NEW.FIELD_ID and lcfir.CONSTRAINT_ID = NEW.CONSTRAINT_ID
			AND lcfir.SMALLEST_VALUE <= NEW.LARGEST_VALUE and NEW.SMALLEST_VALUE <= lcfir.LARGEST_VALUE LIMIT 1;
		SIGNAL SQLSTATE '45000' SET message_text=ERROR_TX;
	END IF;
end GO
delimiter ; 

delimiter GO
create trigger LKUP_CONSTRAINT_FIELD_DATE_RANGE_AFTER_UPDATE after update on LKUP_CONSTRAINT_FIELD_DATE_RANGE
for each row
begin
	DECLARE ERROR_TX VARCHAR(128);
	if exists (select * from LKUP_CONSTRAINT_FIELD_INT_RANGE lcfir where lcfir.APPLICATION_ID = NEW.APPLICATION_ID and lcfir.FIELD_ID = NEW.FIELD_ID and lcfir.CONSTRAINT_ID = NEW.CONSTRAINT_ID AND NEW.SMALLEST_VALUE <> lcfir.SMALLEST_VALUE
		AND lcfir.SMALLEST_VALUE <= NEW.LARGEST_VALUE and NEW.SMALLEST_VALUE <= lcfir.LARGEST_VALUE LIMIT 1) THEN		
		select CONCAT('Range overlaps with ', convert(lcfir.SMALLEST_VALUE, char), '-', convert(lcfir.LARGEST_VALUE, char)) INTO ERROR_TX from LKUP_CONSTRAINT_FIELD_INT_RANGE lcfir
		where lcfir.APPLICATION_ID = NEW.APPLICATION_ID and lcfir.FIELD_ID = NEW.FIELD_ID and lcfir.CONSTRAINT_ID = NEW.CONSTRAINT_ID  AND NEW.SMALLEST_VALUE <> lcfir.SMALLEST_VALUE
			AND lcfir.SMALLEST_VALUE <= NEW.LARGEST_VALUE and NEW.SMALLEST_VALUE <= lcfir.LARGEST_VALUE LIMIT 1;
		SIGNAL SQLSTATE '45000' SET message_text=ERROR_TX;
	END IF;
end GO
delimiter ; 

CREATE TABLE LKUP_CONSTRAINT_FIELD_BIT (
	APPLICATION_ID INT NOT NULL,
	FIELD_ID INT NOT NULL,
	CONSTRAINT_ID INT NOT NULL,
	VALID_VALUE BIT NULL DEFAULT true,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT_APP_FIELD (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID),
	INDEX (VALID_VALUE)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Defines valid truth (or bit) values for a bit constraint.  If unspecified, defaults to true.  NULL is permitted in order to specify that any value is valid.  The NULL value exists to allow a bit constraint to be defined such that a bit value (or fact) must exist, but it actual value is immaterial.';

grant select on LKUP_CONSTRAINT_FIELD_BIT to dfa_user;
grant insert,update,delete on LKUP_CONSTRAINT_FIELD_BIT to dfa_admin;

INSERT INTO `dfa`.`LKUP_CONSTRAINT_FIELD_BIT`
(`APPLICATION_ID`,
`FIELD_ID`,
`CONSTRAINT_ID`,
`MOD_BY`)
VALUES
(1,1,3,'DFA Admin');

CREATE TABLE LKUP_EVENT (
	EVENT_TYP            INT NOT NULL,
	SORT_ORDER           INT DEFAULT 0 NOT NULL,
	MAKE_CURRENT         BIT DEFAULT true NOT NULL,
	EVENT_NM             VARCHAR (20) NOT NULL,
	EVENT_TX             VARCHAR (60) NOT NULL,
	ATTENTION            BIT DEFAULT false NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (EVENT_TYP),
	INDEX (MAKE_CURRENT),
	INDEX (ATTENTION)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='The possible events that may be sent to the event driven DFA.  MAKE_CURRENT controls if this event changes (advances) the current DFA state (if not, the state is added but does not affect the current DFA state).  ATTENTION is a hint to the view layer that this event represents an exceptional condition (such as a rejection, disapproval, return for rework, etc).  SORT_ORDER is also a hint to the view layer how to sort the events in a pull-down list of possible valid events.';

grant select on LKUP_EVENT to dfa_viewer;
grant insert,update,delete on LKUP_EVENT to dfa_admin;

-- Insert this one row because it is used as a default value.
insert into LKUP_EVENT (EVENT_TYP,EVENT_NM,EVENT_TX,MOD_BY) VALUES (1,'Start','Start Action','DFA-Create');
COMMIT;

create table LKUP_STATE (
	STATE_TYP INT NOT NULL,
	STATE_NM VARCHAR(32) NOT NULL,
	STATE_TX VARCHAR(128) NOT NULL,
	ACTIVE BIT(1) NOT NULL DEFAULT 1,
	PSEUDO BIT(1) NOT NULL DEFAULT 0,
	ATTENTION BIT (1) NOT NULL DEFAULT 0,
	EXPECTED_NEXT_EVENT INT NULL,
	ALT_STATE_TYP INT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT_ID  INT NOT NULL DEFAULT 1,
	CONSTRAINT FOREIGN KEY (CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT (CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (ALT_STATE_TYP) REFERENCES LKUP_STATE (STATE_TYP),
	CONSTRAINT CHECK (ACTIVE=0 OR PSEUDO=0),
	PRIMARY KEY (STATE_TYP),
	INDEX (ACTIVE),
	INDEX (ATTENTION),
    INDEX (PSEUDO)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='The possible states that exist in the DFA state graph.  ACTIVE denotes states (and therefore workflows) that are not yet completed.  ATTENTION is a hint to the view layer that this state represents an exceptional condition, such as disapproved, under investigation, cancelled, etc.  PSEUDO denotes a state that is not transitioned into but instead represents an instruction to the DFA processing engine.  The Undo state transitioning to the workflows previous state is an example of such a state.  ALT_STATE_TYP represents a state to try if this state does not satisfy the currently valid constraints.  It is used to implement conditional branching within the DFA model.';

grant select on LKUP_STATE to dfa_viewer;
grant insert,update,delete on LKUP_STATE to dfa_admin;

create table LKUP_EVENT_STATE_TRANS (
	STATE_TYP INT NOT NULL,
	EVENT_TYP INT NOT NULL,
	NEXT_STATE_TYP INT NOT NULL,
	SORT_ORDER INT NULL, -- Overrides LKUP_EVENT.SORT_ORDER if not null.
	EVENT_TX VARCHAR (60) NULL, -- Overrides LKUP_EVENT.EVENT_TX if not null.
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,	
	CONSTRAINT_ID  INT NOT NULL DEFAULT 1,
	CONSTRAINT FOREIGN KEY (CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT (CONSTRAINT_ID),
	PRIMARY KEY (STATE_TYP,EVENT_TYP),
	CONSTRAINT FOREIGN KEY (STATE_TYP) REFERENCES LKUP_STATE (STATE_TYP),
	CONSTRAINT FOREIGN KEY (EVENT_TYP) REFERENCES LKUP_EVENT (EVENT_TYP),
	CONSTRAINT FOREIGN KEY (NEXT_STATE_TYP) REFERENCES LKUP_STATE (STATE_TYP)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='The transitions (verticies) between states via events.  A transition is valid if its constraint is satisfied with update rights, AND its next state is satisfied with update right or there exists an alternate of the next state that is satisfied with update rights.  SORT_ORDER and EVENT_TX exist to allow those event fields to be overridden on a per-transition basis.  Allowing them to be overidden prevents the necessity of polluting the LKUP_EVENT table with similiar events.';

grant select on LKUP_EVENT_STATE_TRANS to dfa_viewer;
grant insert,update,delete on LKUP_EVENT_STATE_TRANS to dfa_admin;

alter table LKUP_STATE ADD CONSTRAINT FOREIGN KEY (STATE_TYP,EXPECTED_NEXT_EVENT) 
	REFERENCES LKUP_EVENT_STATE_TRANS (STATE_TYP,EVENT_TYP);

-- No transitions from inactive states
delimiter GO
CREATE TRIGGER lkup_state_before_update BEFORE UPDATE ON LKUP_STATE 
FOR EACH ROW 
BEGIN
	DECLARE ERROR_TX VARCHAR(128);
	IF (NEW.ACTIVE = 0 AND OLD.ACTIVE = 1) THEN
		IF EXISTS (select * from LKUP_EVENT_STATE_TRANS lest where 
			lest.STATE_TYP = NEW.STATE_TYP) THEN
				SELECT CONCAT('Unable to set event ', convert(NEW.STATE_TYP, char),
				' to inactive because there are 1 or more lkup_event_state_trans transitions from it')
				INTO ERROR_TX;
				SIGNAL SQLSTATE '45000' SET message_text=ERROR_TX;
		END IF;
	END IF;
END GO
delimiter ;

-- No creating transitions from inactive states.
delimiter GO
CREATE TRIGGER lkup_event_state_trans_before_insert BEFORE INSERT ON LKUP_EVENT_STATE_TRANS FOR EACH ROW BEGIN
	IF EXISTS (select * from LKUP_STATE where LKUP_STATE.STATE_TYP=NEW.STATE_TYP
		AND LKUP_STATE.ACTIVE = 0) THEN
			SIGNAL SQLSTATE '45000' SET message_text='Unable to insert transition for inactive state';
	END IF;
END GO
delimiter ;

-- Unit test these triggers.
/*
INSERT INTO LKUP_STATE
	(STATE_TYP, STATE_NM, STATE_TX, MOD_BY)
	VALUES (1, 'First', 'First State', 'TEST');
INSERT INTO LKUP_STATE
	(STATE_TYP, STATE_NM, STATE_TX, MOD_BY)
	VALUES (2, 'Second', 'Second State', 'TEST');
	
INSERT INTO LKUP_EVENT_STATE_TRANS
	(STATE_TYP, EVENT_TYP, NEXT_STATE_TYP, MOD_BY)
	VALUES (1, 1, 2, 'TEST');
	

update LKUP_STATE SET ACTIVE=0 WHERE STATE_TYP = 1; -- Should FAIL.

-- Now, unit test lkup_event_state_trans_before_insert
delete from LKUP_EVENT_STATE_TRANS where STATE_TYP=1 and EVENT_TYP=1;
update LKUP_STATE SET ACTIVE=0 WHERE STATE_TYP = 1; -- Should SUCCEED.

INSERT INTO LKUP_EVENT_STATE_TRANS
	(STATE_TYP, EVENT_TYP, NEXT_STATE_TYP, MOD_BY)
	VALUES (1, 1, 2, 'TEST'); -- Should FAIL.
*/

create table LKUP_WORKFLOW_TYP (
	WORKFLOW_TYP INT NOT NULL PRIMARY KEY,
	WORKFLOW_NM VARCHAR(32) NOT NULL,
	WORKFLOW_TX VARCHAR(128) NOT NULL,
	START_STATE_TYP INT NOT NULL,
	START_EVENT_TYP INT NOT NULL DEFAULT 1,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT_ID  INT NOT NULL DEFAULT 1,
	CONSTRAINT FOREIGN KEY (CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT (CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (START_STATE_TYP) REFERENCES LKUP_STATE (STATE_TYP),
	CONSTRAINT FOREIGN KEY (START_EVENT_TYP) REFERENCES LKUP_EVENT (EVENT_TYP)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Defines the workflows supported by the DFA graph.  The workflow itself is defined by the closure (map) from the start state of the workflow type.';

grant select on LKUP_WORKFLOW_TYP to dfa_viewer;
grant insert,update,delete on LKUP_WORKFLOW_TYP to dfa_admin;

create table LKUP_WORKFLOW_TYP_ADDITIONAL (
	CONSTRAINT_ID INT NOT NULL DEFAULT 1,
	WORKFLOW_TYP INT NOT NULL,
	FIELD_ID INT NOT NULL,
    FIELD_ORDER SMALLINT DEFAULT 0 NOT NULL,
    PRIMARY KEY (CONSTRAINT_ID,WORKFLOW_TYP,FIELD_ID),
	CONSTRAINT FOREIGN KEY (CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT (CONSTRAINT_ID),
    CONSTRAINT FOREIGN KEY (WORKFLOW_TYP) REFERENCES LKUP_WORKFLOW_TYP (WORKFLOW_TYP),
    CONSTRAINT FOREIGN KEY (FIELD_ID) REFERENCES LKUP_FIELD (FIELD_ID)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Defines additional data elements that should be displayed along with the workflow.';

grant select on LKUP_WORKFLOW_TYP_ADDITIONAL to dfa_user;
grant insert,update,delete on LKUP_WORKFLOW_TYP_ADDITIONAL to dfa_admin;

create table LKUP_WORKFLOW_STATE_TYP_CREATE (
	STATE_TYP INT NOT NULL,
	WORKFLOW_TYP INT NOT NULL,
	SUB_STATE BIT DEFAULT true,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT_ID INT NOT NULL DEFAULT 2, -- Executes as system.
	CONSTRAINT FOREIGN KEY (CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT (CONSTRAINT_ID),
	PRIMARY KEY (STATE_TYP,	WORKFLOW_TYP),
	FOREIGN KEY (STATE_TYP) REFERENCES LKUP_STATE (STATE_TYP),
	FOREIGN KEY (WORKFLOW_TYP)  REFERENCES LKUP_WORKFLOW_TYP (WORKFLOW_TYP)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Defines workflows that should be launched (created) when this state is entered and their constraints are satisfied.  Workflows may be subordinate to specific parent workflow states, and such states may be set up to transition only when all subordinate workflows are completed.  This supports workflows with parallel tasks.  Alternately, workflows may be created that are independent of their spawning workflow state.';

grant select on LKUP_WORKFLOW_STATE_TYP_CREATE to dfa_user;
grant insert,update,delete on LKUP_WORKFLOW_STATE_TYP_CREATE to dfa_admin;

create table DFA_WORKFLOW (
	DFA_WORKFLOW_ID BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	WORKFLOW_TYP INT NOT NULL,
	COMMENT_TX MEDIUMTEXT NULL,
	SPAWN_DFA_WORKFLOW_ID BIGINT UNSIGNED NULL,
	SPAWN_DFA_STATE_ID MEDIUMINT UNSIGNED NULL,
	SUB_STATE BIT DEFAULT false, -- Substate of 0 with non-null spawn means an independent workflow is spawned.
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT FK_WORKFLOW_TYP FOREIGN KEY (WORKFLOW_TYP) REFERENCES LKUP_WORKFLOW_TYP (WORKFLOW_TYP),
	CONSTRAINT SUB_STATE_SPAWN CHECK (ISNULL(SPAWN_DFA_WORKFLOW_ID) = ISNULL(SPAWN_DFA_STATE_ID) AND (SUB_STATE = 0 OR (SPAWN_DFA_WORKFLOW_ID IS NOT NULL AND SPAWN_DFA_STATE_ID IS NOT NULL))),
	INDEX (SUB_STATE)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='An instance of a given workflow.  This is the table that is typically bound to an entity via a binding table.';

grant select on DFA_WORKFLOW to dfa_view;
grant update (COMMENT_TX,MOD_BY) on DFA_WORKFLOW to dfa_user;
grant insert,update,delete on DFA_WORKFLOW to dfa_admin;


create table DFA_WORKFLOW_STATE (
	DFA_WORKFLOW_ID BIGINT UNSIGNED NOT NULL,
	DFA_STATE_ID MEDIUMINT UNSIGNED NOT NULL DEFAULT 0,
	IS_CURRENT BIT DEFAULT true,
	IS_PASSIVE BIT DEFAULT false,
	STATE_TYP INT NOT NULL,
	EVENT_TYP INT NOT NULL,
	PARENT_STATE_ID MEDIUMINT UNSIGNED NOT NULL DEFAULT 0,
	UNDO_STATE_ID MEDIUMINT UNSIGNED NULL DEFAULT 0, /* Magic 0 value enables trigger to detect missing column. */
	COMMENT_TX MEDIUMTEXT NULL, 
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (DFA_WORKFLOW_ID,DFA_STATE_ID),
	CONSTRAINT FK_DFA_WORKFLOW FOREIGN KEY (DFA_WORKFLOW_ID) REFERENCES DFA_WORKFLOW (DFA_WORKFLOW_ID),
	CONSTRAINT FK_LKUP_STATE FOREIGN KEY (STATE_TYP) REFERENCES LKUP_STATE (STATE_TYP),
	CONSTRAINT FK_LKUP_EVENT FOREIGN KEY (EVENT_TYP) REFERENCES LKUP_EVENT (EVENT_TYP),	
	CONSTRAINT FK_PARENT_STATE FOREIGN KEY (DFA_WORKFLOW_ID,PARENT_STATE_ID) references DFA_WORKFLOW_STATE (DFA_WORKFLOW_ID,DFA_STATE_ID),
	CONSTRAINT FK_UNDO_STATE FOREIGN KEY (DFA_WORKFLOW_ID,UNDO_STATE_ID) references DFA_WORKFLOW_STATE (DFA_WORKFLOW_ID,DFA_STATE_ID),
	CONSTRAINT PARENT_NOT_FUTURE CHECK (PARENT_STATE_ID <= DFA_STATE_ID),
	CONSTRAINT UNDO_IS_PAST CHECK (UNDO_STATE_ID IS NULL OR UNDO_STATE_ID < DFA_STATE_ID),
	CONSTRAINT DFA_STATE_ID_NOT_0 CHECK (DFA_STATE_ID > 0),
	INDEX (IS_CURRENT), 
	INDEX (IS_PASSIVE)
	)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='An instance of a workflow state.  There is always exactly 1 current state with IS_CURRENT = 1.  IS_PASSIVE is true when a state is created by an event with LKUP_EVENT.MAKE_CURRENT of false.  PARENT_STATE_ID = DFA_STATE_ID for a non-passive state.  For passive states, PARENT_STATE_ID is the state that was current when that state was inserted.  UNDO_STATE_ID is the state that will be transitioned to if an Undo pseudo state is applied.  It is NULL (indicating that undo is invalid) if state is at the start state for the given DFA type.';

grant select on DFA_WORKFLOW_STATE to dfa_view;
grant update (EVENT_TYP,COMMENT_TX,MOD_BY) on DFA_WORKFLOW_STATE to dfa_user;
grant insert,update,delete on DFA_WORKFLOW_STATE to dfa_admin;

-- Now, we can add the foreign key constraint for the spawned DFA workflow state.
alter table DFA_WORKFLOW ADD CONSTRAINT FOREIGN KEY (SPAWN_DFA_WORKFLOW_ID,SPAWN_DFA_STATE_ID) REFERENCES DFA_WORKFLOW_STATE (DFA_WORKFLOW_ID,DFA_STATE_ID);

-- Workaround for MariaDB limitation of not being able to clear is current
-- from within trigger: immediately after performing a DFA operation, delete
-- any rows in this table that belong to the workflow id.  The delete trigger
-- of this table will set the IS_CURRENT bit of the corresponding 
-- DFA_WORKFLOW_STATE to 0.
create table tmp_dfa_clear_current (
	DFA_WORKFLOW_ID BIGINT UNSIGNED NOT NULL,
	DFA_STATE_ID MEDIUMINT UNSIGNED NOT NULL,
	PRIMARY KEY (DFA_WORKFLOW_ID,DFA_STATE_ID),
    FOREIGN KEY (DFA_WORKFLOW_ID,DFA_STATE_ID) REFERENCES DFA_WORKFLOW_STATE (DFA_WORKFLOW_ID,DFA_STATE_ID)
)COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='This internal table is a workaround for the maria db limitation of not being able to update a table from within its trigger.  Instead of updating, the DFA_WORKFLOW_STATE insert trigger inserts a row for each state that should have IS_CURRENT cleared.  Immediately after inserting a DFA_WORKFLOW_STATE, execute delete from tmp_dfa_clear_current where tmp_dfa_clear_current.DFA_WORKFLOW_ID = <the dfa workflow being processed>.  The delete trigger of this table will clear the IS_CURRENT flags.';

-- No grants, runs in context of the stored proc (i.e. as root).

delimiter GO
CREATE TRIGGER tmp_dfa_clear_current_AFTER_DELETE AFTER DELETE ON tmp_dfa_clear_current
FOR EACH ROW BEGIN
	UPDATE DFA_WORKFLOW_STATE SET IS_CURRENT=0 WHERE IS_CURRENT=1 AND DFA_WORKFLOW_ID = OLD.DFA_WORKFLOW_ID and DFA_STATE_ID = OLD.DFA_STATE_ID;
END GO
delimiter ;

delimiter GO
CREATE TRIGGER DFA_WORKFLOW_AFTER_INSERT AFTER INSERT ON DFA_WORKFLOW FOR EACH ROW BEGIN
	DECLARE STATE_TYP, EVENT_TYP INT;
	select START_STATE_TYP, START_EVENT_TYP INTO STATE_TYP, EVENT_TYP FROM LKUP_WORKFLOW_TYP WHERE
		LKUP_WORKFLOW_TYP.WORKFLOW_TYP = NEW.WORKFLOW_TYP;
	
	INSERT DFA_WORKFLOW_STATE (DFA_WORKFLOW_ID,DFA_STATE_ID,IS_CURRENT,STATE_TYP,EVENT_TYP,MOD_BY) 
	VALUES (NEW.DFA_WORKFLOW_ID, 1, 1, STATE_TYP, EVENT_TYP, NEW.MOD_BY);
    delete from tmp_dfa_clear_current where DFA_WORKFLOW_ID = NEW.DFA_WORKFLOW_ID;
END GO
delimiter ;

delimiter GO
CREATE TRIGGER DFA_WORKFLOW_STATE_BEFORE_INSERT BEFORE INSERT ON DFA_WORKFLOW_STATE FOR EACH ROW BEGIN
	DECLARE NEXT_STATE_ID MEDIUMINT UNSIGNED;
	DECLARE CURRENT_STATE_ID MEDIUMINT UNSIGNED;
	IF (NEW.DFA_STATE_ID IS NULL OR NEW.DFA_STATE_ID = 0) THEN
		SELECT IFNULL(MAX(DFA_STATE_ID)+1,1) INTO NEXT_STATE_ID 
		FROM DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = NEW.DFA_WORKFLOW_ID;
		SET NEW.DFA_STATE_ID = NEXT_STATE_ID;
	END IF;

	-- Note: NEW.UNDO_STATE_ID IS NULL is a valid incoming value.
	IF (NEW.IS_CURRENT = 0 OR NEW.UNDO_STATE_ID = 0) THEN
		SELECT DFA_WORKFLOW_STATE.DFA_STATE_ID INTO CURRENT_STATE_ID FROM DFA_WORKFLOW_STATE 
		where DFA_WORKFLOW_STATE.DFA_WORKFLOW_ID = NEW.DFA_WORKFLOW_ID 
		AND DFA_WORKFLOW_STATE.DFA_STATE_ID <> NEW.DFA_STATE_ID AND DFA_WORKFLOW_STATE.IS_CURRENT = 1 
        ORDER BY DFA_STATE_ID DESC LIMIT 1;
	END IF;

	IF (NEW.IS_CURRENT = 1) THEN
		insert tmp_dfa_clear_current (DFA_WORKFLOW_ID,DFA_STATE_ID) 
        select DFA_WORKFLOW_ID,DFA_STATE_ID from DFA_WORKFLOW_STATE where DFA_WORKFLOW_ID = NEW.DFA_WORKFLOW_ID and IS_CURRENT = 1 AND DFA_STATE_ID <> NEW.DFA_STATE_ID;
		SET NEW.PARENT_STATE_ID = NEW.DFA_STATE_ID;
		SET NEW.IS_PASSIVE = 0;
	ELSE
		SET NEW.IS_PASSIVE = 1;
		SET NEW.PARENT_STATE_ID = CURRENT_STATE_ID;
	END IF;
	
	IF (NEW.UNDO_STATE_ID = 0) THEN
		SET NEW.UNDO_STATE_ID = CURRENT_STATE_ID;
	END IF;
END GO
delimiter ;

/*
-- Unit test for inserting a workflow state.
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

insert session_dfa_constraint (CONSTRAINT_ID, ALLOW_UPDATE, IS_RESPONSIBLE)
VALUES (1,1,0);

SET @dfa_act_state_ref_id=0;

select concat(convert(current_timestamp(), char), ' Test') INTO @dfa_workflow_insert_unit_test;

INSERT INTO DFA_WORKFLOW
(WORKFLOW_TYP,COMMENT_TX,MOD_BY)
VALUES (1, 'Test start new workflow triggers.', @dfa_workflow_insert_unit_test);

SELECT DFA_WORKFLOW_ID into @dfa_workflow_insert_ut_id FROM DFA_WORKFLOW WHERE WORKFLOW_TYP=1 AND MOD_BY=@dfa_workflow_insert_unit_test;
-- SELECT * FROM DFA_WORKFLOW where DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id;
-- SELECT * FROM DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id;

-- Now, insert the next state as current and verify the current current state is reset.
INSERT INTO DFA_WORKFLOW_STATE
(DFA_WORKFLOW_ID,IS_CURRENT,STATE_TYP,EVENT_TYP,MOD_BY)
VALUES (@dfa_workflow_insert_ut_id,1,2,1,@dfa_workflow_insert_unit_test);

delete from tmp_dfa_clear_current where tmp_dfa_clear_current.DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id;

-- Add a passive state, verify that it is not current and marked as passive.
INSERT INTO DFA_WORKFLOW_STATE
(DFA_WORKFLOW_ID,IS_CURRENT,STATE_TYP,EVENT_TYP,MOD_BY)
VALUES (@dfa_workflow_insert_ut_id,0,1,1,@dfa_workflow_insert_unit_test);

delete from tmp_dfa_clear_current where tmp_dfa_clear_current.DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id;

-- Now, insert the next state as current and verify the current current state is reset.
INSERT INTO DFA_WORKFLOW_STATE
(DFA_WORKFLOW_ID,IS_CURRENT,STATE_TYP,EVENT_TYP,MOD_BY)
VALUES (@dfa_workflow_insert_ut_id,1,2,1,@dfa_workflow_insert_unit_test);

delete from tmp_dfa_clear_current where tmp_dfa_clear_current.DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id;

-- OK, verify the results.

select CASE WHEN (SELECT count(*) FROM DFA_WORKFLOW_STATE WHERE DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id) = 
(select count(*) from session_dfa_workflow_state sdws where sdws.DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id and sdws.OUTPUT=1)
	THEN 'PASS' ELSE 'FAIL' END as RESULT;

SELECT CASE WHEN IS_PASSIVE=0 AND UNDO_STATE_ID IS NULL AND PARENT_STATE_ID=1 THEN 'PASS' ELSE 'FAIL 1' END as RESULT from DFA_WORKFLOW_STATE where DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id AND DFA_STATE_ID=1
UNION SELECT CASE WHEN IS_PASSIVE=0 AND PARENT_STATE_ID=2 AND UNDO_STATE_ID = 1 THEN 'PASS' ELSE 'FAIL 2' END as RESULT from DFA_WORKFLOW_STATE where DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id AND DFA_STATE_ID=2
UNION SELECT CASE WHEN IS_PASSIVE=1 AND PARENT_STATE_ID=2 THEN 'PASS' ELSE 'FAIL 3' END as RESULT from DFA_WORKFLOW_STATE where DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id AND DFA_STATE_ID=3
UNION SELECT CASE WHEN IS_PASSIVE=0 AND PARENT_STATE_ID=4 AND UNDO_STATE_ID=2 THEN 'PASS' ELSE 'FAIL 4' END as RESULT from DFA_WORKFLOW_STATE where DFA_WORKFLOW_ID = @dfa_workflow_insert_ut_id AND DFA_STATE_ID=4;
*/
create table tmp_dfa_workflow_state (
	CONN_ID BIGINT UNSIGNED NOT NULL DEFAULT 0,
	REF_ID  MEDIUMINT DEFAULT 0 NOT NULL,
	DFA_WORKFLOW_ID BIGINT UNSIGNED NOT NULL,
	DFA_STATE_ID MEDIUMINT UNSIGNED NOT NULL,
	OUTPUT BIT DEFAULT false,
	PRIMARY KEY (CONN_ID,REF_ID,DFA_WORKFLOW_ID,DFA_STATE_ID),
	FOREIGN KEY (DFA_WORKFLOW_ID,DFA_STATE_ID) REFERENCES DFA_WORKFLOW_STATE (DFA_WORKFLOW_ID,DFA_STATE_ID),
	INDEX (OUTPUT)	
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='This is a per-connection id work table of DFA_WORKFLOW_STATES.  If @dfa_act_state_ref_id >= 0, an entry will be inserted for the current connection and REF_ID = @dfa_act_state_ref_id for any dfa state created by the connection by the DFA_WORKFLOW_STATE after insert trigger.  Such rows will have OUTPUT = 1.';

grant select,insert,update,delete on tmp_dfa_workflow_state to dfa_admin;

delimiter GO
CREATE TRIGGER tmp_dfa_workflow_state_before_insert BEFORE INSERT ON tmp_dfa_workflow_state FOR EACH ROW BEGIN
	SET NEW.CONN_ID = CONNECTION_ID();
END GO
delimiter ;

create or replace view ref_dfa_workflow_state AS
	select REF_ID, DFA_WORKFLOW_ID, DFA_STATE_ID, OUTPUT from tmp_dfa_workflow_state where CONN_ID = CONNECTION_ID();

grant select,insert,update,delete on ref_dfa_workflow_state to dfa_user;

create or replace view session_dfa_workflow_state AS
	select DFA_WORKFLOW_ID, DFA_STATE_ID, OUTPUT from tmp_dfa_workflow_state where CONN_ID = CONNECTION_ID() AND REF_ID=0;

grant select,insert,update,delete on session_dfa_workflow_state to dfa_user;

create table tmp_user_role (
	CONN_ID BIGINT UNSIGNED NOT NULL DEFAULT 0,
	REF_ID  MEDIUMINT DEFAULT 0 NOT NULL,
	ROLE_NM VARCHAR(32),
	PRIMARY KEY (CONN_ID,REF_ID,ROLE_NM)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Per-connection work table that should be populated with the logged in user roles.';

grant select,insert,update,delete on tmp_user_role to dfa_admin;

delimiter GO
CREATE TRIGGER tmp_user_role_before_insert BEFORE INSERT ON tmp_user_role FOR EACH ROW BEGIN
	SET NEW.CONN_ID = CONNECTION_ID();
END GO
delimiter ;

create or replace view ref_user_role as 
	SELECT REF_ID, ROLE_NM FROM tmp_user_role where CONN_ID = CONNECTION_ID();
	
grant select,insert,update,delete on ref_user_role to dfa_user;

create or replace view session_user_role as 
	SELECT ROLE_NM FROM tmp_user_role where CONN_ID = CONNECTION_ID() AND REF_ID = 0;
	
grant select,insert,update,delete on session_user_role to dfa_view;

create table tmp_dfa_field_value (
	CONN_ID BIGINT UNSIGNED NOT NULL DEFAULT 0,
	FIELD_ID INT NOT NULL,
    DISPLAY_VALUE BIT DEFAULT false,
    FIELD_ORDER SMALLINT DEFAULT 0 NOT NULL,
	INT_VALUE BIGINT NULL,
    BIT_VALUE BIT NULL,
    DATE_VALUE DATE NULL,
    CHAR_VALUE VARCHAR (8191),
	PRIMARY KEY (CONN_ID,FIELD_ID),
    INDEX (DISPLAY_VALUE desc, FIELD_ORDER),
    INDEX (BIT_VALUE),
    INDEX (DATE_VALUE),
    INDEX (INT_VALUE)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Per-connection work table that is populated with the actual values for fields.  Should be populated with the union of fields mentioned by LKUP_WORKFLOW_TYP_ADDITIONAL (with DISPLAY_VALUE = true and FIELD_ORDER defined from it), and LKUP_CONSTRAINT_APP_FIELD fields used for the given operation (or all of them used by a given application).';

grant select,insert,update,delete on tmp_dfa_field_value to dfa_admin;

delimiter GO
CREATE TRIGGER tmp_dfa_field_value_before_insert BEFORE INSERT ON tmp_dfa_field_value FOR EACH ROW BEGIN
	SET NEW.CONN_ID = CONNECTION_ID();
END GO
delimiter ;

create or replace view session_dfa_field_value as
	select FIELD_ID, DISPLAY_VALUE, INT_VALUE, BIT_VALUE, DATE_VALUE, CHAR_VALUE from tmp_dfa_field_value where CONN_ID = CONNECTION_ID();

grant select,insert,update,delete on session_dfa_field_value to dfa_view;

create table tmp_dfa_constraint (
	CONN_ID BIGINT UNSIGNED NOT NULL DEFAULT 0,
	REF_ID  MEDIUMINT DEFAULT 0 NOT NULL,
	CONSTRAINT_ID INT NOT NULL,
	ALLOW_UPDATE    BIT DEFAULT true NOT NULL,
	IS_RESPONSIBLE     BIT DEFAULT false NOT NULL,
	PRIMARY KEY (CONN_ID, REF_ID, CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT (CONSTRAINT_ID),
	CONSTRAINT CHECK (ALLOW_UPDATE = true OR IS_RESPONSIBLE = false),
	CONSTRAINT CHECK (CONSTRAINT_ID <> 0) -- 0 means nobody or disabled.
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
COMMENT='Per-connection constraints that have been satisfied by the current user x current entity x current workflow.  Existence of a row indicates Show is satisfied.  Likewise ALLOW_UPDATE and IS_RESPONSIBLE indicate that these are satisfied.  IS_RESPONSIBLE may not be true unless ALLOW_UPDATE is also true.';
grant select,insert,update,delete on tmp_dfa_constraint to dfa_admin;

delimiter GO
CREATE TRIGGER tmp_dfa_constraint_before_insert BEFORE INSERT ON tmp_dfa_constraint FOR EACH ROW BEGIN
	SET NEW.CONN_ID = CONNECTION_ID();
END GO
delimiter ;

create or replace view ref_dfa_constraint as 
	SELECT REF_ID, CONSTRAINT_ID, ALLOW_UPDATE, IS_RESPONSIBLE FROM tmp_dfa_constraint where CONN_ID = CONNECTION_ID();
	
grant select,insert,update,delete on ref_dfa_constraint to dfa_user;

create or replace view session_dfa_constraint as 
	SELECT CONSTRAINT_ID, ALLOW_UPDATE, IS_RESPONSIBLE FROM tmp_dfa_constraint where CONN_ID = CONNECTION_ID() AND REF_ID = 0;
grant select,insert,update,delete on session_dfa_constraint to dfa_user;
	
delimiter GO
CREATE TRIGGER DFA_WORKFLOW_STATE_AFTER_INSERT AFTER INSERT ON DFA_WORKFLOW_STATE FOR EACH ROW BEGIN
	IF (@dfa_act_state_ref_id >= 0) THEN
		insert into ref_dfa_constraint (REF_ID, DFA_WORKFLOW_ID, DFA_STATE_ID, OUTPUT)
		VALUES (@dfa_act_state_ref_id, NEW.DFA_WORKFLOW_ID, NEW.DFA_STATE_ID, 1);
	END IF;
	
    /*
    -- This code will have to be moved to a stored proc.
	IF EXISTS (SELECT * FROM LKUP_WORKFLOW_STATE_TYP_CREATE WHERE STATE_TYP = NEW.STATE_TYP) THEN 
	DECLARE dfa_system_constraint_ref_id MEDIUMINT default 0;
	DECLARE WORKFLOW_TYP INT DEFAULT NULL;
	DECLARE SUB_STATE BIT;

		select lwstc.WORKFLOW_TYP, lwstc.SUB_STATE into WORKFLOW_TYP, SUB_STATE
		FROM LKUP_WORKFLOW_STATE_TYP_CREATE lwstc join ref_dfa_constraint create_constraint ON
			create_constraint.CONSTRAINT_ID = lwstc.CONSTRAINT_ID AND create_constraint.REF_ID = dfa_system_constraint_ref_id
			JOIN LKUP_WORKFLOW_TYP lwt ON lwt.WORKFLOW_TYP = lwstc.WORKFLOW_TYP
			JOIN ref_dfa_constraint workflow_typ_constraint ON workflow_typ_constraint.CONSTRAINT_ID = lwt.CONSTRAINT_ID AND workflow_typ_constraint.REF_ID = dfa_system_constraint_ref_id
		where lwstc.STATE_TYP = NEW.STATE_TYP AND create_constraint.ALLOW_UPDATE=1 AND workflow_typ_constraint.ALLOW_UPDATE=1;	
	
		IF (WORKFLOW_TYP IS NOT NULL) THEN		
			insert DFA_WORKFLOW (SPAWN_DFA_WORKFLOW_ID,SPAWN_DFA_STATE_ID,MOD_BY,WORKFLOW_TYP,SUB_STATE)
			VALUES (NEW.DFA_WORKFLOW_ID, NEW.DFA_STATE_ID, NEW.MOD_BY, WORKFLOW_TYP, SUB_STATE);
		END IF;
	END IF ;
    */
END GO
delimiter ;

flush PRIVILEGES;
