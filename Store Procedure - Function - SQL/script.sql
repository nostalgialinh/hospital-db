--question a--
update admission
set fee = fee*1.1
where date_of_disc is null and date_of_adm >= to_date('2020-09-01','yyyy-mm-dd')

	
--question b--
select distinct o.pid, lname, fname, dob, address, phone, gender
from outpatient o
join examination e
on o.pid = e.pid
where did = (select ecode from doctor d where concat(lname,' ',fname) = 'Nguyen Anh')
union
select distinct i.pid, lname, fname, dob, address, phone, gender
from inpatient i
join treat t
on i.pid = t.pid
where did = (select ecode from doctor d where concat(lname,' ',fname) = 'Nguyen Anh');



--question c--
CREATE OR REPLACE FUNCTION get_medication_costs_by_patient(patient_id INT)
RETURNS TABLE (
    sid INT,
    total_cost BIGINT  -- Adjust type as needed
) AS $$
BEGIN
    RETURN QUERY
    select distinct x.sid, x.total_cost
	from (
		(select distinct tco.sid, sum(quantity * price) as total_cost
		from t_consists_of tco
		join medication m
		on m.medication_id = tco.mid 
		join treat t
		on tco.sid = t.sid
		where t.pid = patient_id
		group by tco.sid)
	union
		(select distinct eco.sid, sum(quantity * price) as total_cost
		from e_consists_of eco
		join medication m
		on m.medication_id = eco.mid 
		join examination e 
		on eco.sid = e.sid
		where e.pid = patient_id
		group by eco.sid)
		) x
	order by x.sid asc;
END;
$$ LANGUAGE plpgsql;



SELECT * FROM get_medication_costs_by_patient(102);


--question d--
CREATE OR REPLACE PROCEDURE get_patient_counts(
    start_date DATE,
    end_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    record RECORD;
BEGIN
    FOR record IN 
        SELECT DISTINCT d.ecode, 
                        CONCAT(d.lname, ' ', d.fname) AS full_name, 
                        COUNT(DISTINCT x.pid) AS patient_count
        FROM doctor d
        JOIN (
            (SELECT t.pid, t.did 
             FROM treat t
             JOIN admission a ON a.pid = t.pid 
             WHERE (a.date_of_disc > start_date AND a.date_of_adm <= end_date) OR 
                   (a.date_of_adm < end_date AND a.date_of_disc IS NULL))
            UNION 
            (SELECT e.pid, e.did 
             FROM examination e
             WHERE e.e_date >= start_date AND e.e_date <= end_date)
        ) x ON d.ecode = x.did 
        GROUP BY d.ecode, d.lname, d.fname
        ORDER BY COUNT(DISTINCT x.pid) ASC
    LOOP
        RAISE NOTICE 'Ecode: %, Full Name: %, Patient Count: %', record.ecode, record.full_name, record.patient_count;
    END LOOP;
END;
$$;


CALL get_patient_counts('2000-09-28', '2024-12-02');

