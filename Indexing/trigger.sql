-- USE_CASE: Check whether the dean that being inserted is actually currently working for the corresponding department,
-- if not then raise exception
CREATE OR REPLACE FUNCTION validate_dept_mgr()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.mgr_code IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM doctor D
            WHERE D.ecode = NEW.mgr_code
              AND D.dcode = NEW.dcode
        ) THEN
            RAISE EXCEPTION 'Employee with id:(%), does not belong to the department (%)', NEW.mgr_code, NEW.dtitle;
        END IF;
    END IF;

    RETURN NEW; 
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER update_dept_mgr_valid
BEFORE INSERT OR UPDATE ON department
FOR EACH ROW
EXECUTE FUNCTION validate_dept_mgr();

-- USE_CASE: generate corresponding ipid opid
CREATE OR REPLACE FUNCTION gen_patient_pid()
RETURNS TRIGGER AS $$
DECLARE
    prefix TEXT;
BEGIN
    IF TG_TABLE_NAME = 'inpatient' THEN
        prefix := 'IP';
		NEW.ipid := CONCAT(prefix, LPAD(NEW.pid::TEXT, 9, '0'));
    ELSIF TG_TABLE_NAME = 'outpatient' THEN
        prefix := 'OP';
		NEW.opid := CONCAT(prefix, LPAD(NEW.pid::TEXT, 9, '0'));
    ELSE
        RAISE EXCEPTION 'Unknown table for patient ID generation: %', TG_TABLE_NAME;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER insert_patient_ipid
BEFORE INSERT OR UPDATE ON inpatient
FOR EACH ROW
EXECUTE FUNCTION gen_patient_pid();

CREATE OR REPLACE TRIGGER insert_patient_opid
BEFORE INSERT OR UPDATE ON outpatient
FOR EACH ROW
EXECUTE FUNCTION gen_patient_pid();

-- USE CASE: check whether information of inpatient and outpatient with same pid is similar
CREATE OR REPLACE FUNCTION pid_consistency_insert()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_TABLE_NAME = 'inpatient' THEN
		IF EXISTS (SELECT 1 FROM outpatient O where NEW.pid = O.pid) THEN
			IF EXISTS
			(SELECT 1 FROM outpatient O where
				lname= NEW.lname  AND
				fname= NEW.fname  AND
				dob= NEW.dob  AND
				address= NEW.address  AND
				phone= NEW.phone  AND
				gender= NEW.gender AND
				pid = NEW.pid
			) THEN
				RAISE NOTICE 'Patient with PID % is also an outpatient', NEW.pid;
			ELSE
				RAISE EXCEPTION 'Incosistent information of patient with pid %', NEW.pid;
			END IF;
		END IF;
	END IF;
	IF TG_TABLE_NAME = 'outpatient' THEN
		IF EXISTS (SELECT 1 FROM inpatient I where NEW.pid = I.pid) THEN
			IF EXISTS
			(SELECT 1 FROM inpatient  where
				lname= NEW.lname AND
				fname= NEW.fname AND
				dob= NEW.dob AND
				address= NEW.address AND
				phone= NEW.phone AND
				gender= NEW.gender AND
				pid = NEW.pid
			) THEN
				RAISE NOTICE 'Patient with PID % is also an inpatient', NEW.pid;
			ELSE
				RAISE EXCEPTION 'Incosistent information of patient with pid %', NEW.pid;
			END IF;
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE TRIGGER pid_consistency_inpatient
BEFORE INSERT ON inpatient
FOR EACH ROW EXECUTE FUNCTION pid_consistency_insert();

CREATE OR REPLACE TRIGGER pid_consistency_outpatient
BEFORE INSERT ON outpatient
FOR EACH ROW EXECUTE FUNCTION pid_consistency_insert();

--use case: ensure consistency when update, if consistency --> pass, else update the other table also
CREATE OR REPLACE FUNCTION patient_consistency_update_func()
RETURNS TRIGGER AS $$
declare
	tfname text;
	tlname text;
	tgender text;
	tphone text;
	taddress text;
	tdob date;
BEGIN
	IF TG_TABLE_NAME = 'inpatient' then
		if exists (select 1 from outpatient where pid = NEW.pid) then
			select fname, lname, gender, phone, address, dob into tfname, tlname, tgender, tphone, taddress, tdob
			from outpatient where pid = NEW.pid;
			if not (tfname = NEW.fname and 
					tlname = NEW.lname and 
					tgender= NEW.gender and 
					tphone = NEW.phone and 
					taddress = NEW.address and 
					tdob = NEW.dob
					) then
					update outpatient set fname = NEW.fname, lname = NEW.lname, gender = NEW.gender,
					phone = NEW.phone, address = NEW.address, dob = NEW.dob where pid = NEW.pid;
			end if;
		end if;
	elsif TG_TABLE_NAME = 'outpatient' then
		if exists (select 1 from inpatient where pid = NEW.pid) then
			select fname, lname, gender, phone, address, dob into tfname, tlname, tgender, tphone, taddress, tdob
			from inpatient where pid = NEW.pid;
			if not (tfname = NEW.fname and 
					tlname = NEW.lname and 
					tgender= NEW.gender and 
					tphone = NEW.phone and 
					taddress = NEW.address and 
					tdob = NEW.dob
					) then
					update inpatient set fname = NEW.fname, lname = NEW.lname, gender = NEW.gender,
					phone = NEW.phone, address = NEW.address, dob = NEW.dob where pid = NEW.pid;
			end if;
		end if;
	end if;
	return NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER patient_consistency_update_outpatient
AFTER UPDATE ON outpatient 
FOR EACH ROW EXECUTE FUNCTION patient_consistency_update_func();

CREATE OR REPLACE TRIGGER patient_consistency_update_inpatient
AFTER UPDATE ON inpatient 
FOR EACH ROW EXECUTE FUNCTION patient_consistency_update_func();

--USE CASE: QUICKLY INSERT PATIENT IF THEY ALREADY EXISTED IN EITHER PATIENT TALBES
CREATE OR REPLACE FUNCTION insert_patient(target_pid INT, target_table TEXT)
RETURNS boolean AS $successful$
BEGIN
    IF target_table = 'outpatient' THEN
        IF EXISTS (SELECT 1 FROM inpatient I WHERE I.pid = target_pid) THEN
            INSERT INTO outpatient (pid, fname, lname, gender, phone, address, dob)
            SELECT pid, fname, lname, gender, phone, address, dob FROM inpatient WHERE pid = target_pid;
			RETURN TRUE;
        ELSE
            RAISE NOTICE 'This patient PID % does not exist', target_pid;
			RETURN FALSE;
        END IF;
    ELSIF target_table = 'inpatient' THEN
        IF EXISTS (SELECT 1 FROM outpatient O WHERE O.pid = target_pid) THEN
            INSERT INTO inpatient (pid, fname, lname, gender, phone, address, dob)
            SELECT pid, fname, lname, gender, phone, address, dob FROM outpatient WHERE pid = target_pid;
			RETURN TRUE;
		ELSE
            RAISE NOTICE 'This patient PID % does not exist', target_pid;
			RETURN FALSE;
		END IF;
    END IF;
	RETURN successful;
END;
$successful$ LANGUAGE plpgsql;
