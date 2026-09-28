-- ============================================================
-- Vistas adaptadas de MariaDB a PostgreSQL
-- Base de datos: employees
-- Autor: Ruben Churqui Limachi
-- Fecha: 28 de Septiembre de 2026
-- ============================================================

-- Vista 1: dept_emp_latest_date (crear PRIMERO porque current_dept_emp depende de ella)
CREATE OR REPLACE VIEW public.dept_emp_latest_date AS
SELECT
    dept_emp.emp_no,
    MAX(dept_emp.from_date) AS from_date,
    MAX(dept_emp.to_date) AS to_date
FROM dept_emp
GROUP BY dept_emp.emp_no;

-- Vista 2: current_dept_emp (depende de dept_emp_latest_date)
CREATE OR REPLACE VIEW public.current_dept_emp AS
SELECT
    l.emp_no,
    d.dept_no,
    l.from_date,
    l.to_date
FROM dept_emp d
JOIN dept_emp_latest_date l
    ON d.emp_no = l.emp_no
    AND d.from_date = l.from_date
    AND l.to_date = d.to_date;
