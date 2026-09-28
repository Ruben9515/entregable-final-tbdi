-- ============================================================
-- Script SQL adaptado de MariaDB a PostgreSQL
-- Base de datos: employees
-- Autor: Ruben Churqui Limachi
-- Fecha: 28 de Septiembre de 2026
-- ============================================================

-- Crear tipo ENUM para gender
CREATE TYPE public.gender_type AS ENUM ('M', 'F');

-- ------------------------------------------------------------
-- Tabla: departments
-- ------------------------------------------------------------
CREATE TABLE public.departments (
    dept_no CHAR(4) NOT NULL,
    dept_name VARCHAR(40) NOT NULL,
    CONSTRAINT departments_pk PRIMARY KEY (dept_no),
    CONSTRAINT departments_dept_name_key UNIQUE (dept_name)
);

-- ------------------------------------------------------------
-- Tabla: employees
-- ------------------------------------------------------------
CREATE TABLE public.employees (
    emp_no INTEGER NOT NULL,
    birth_date DATE NOT NULL,
    first_name VARCHAR(14) NOT NULL,
    last_name VARCHAR(16) NOT NULL,
    gender public.gender_type NOT NULL,
    hire_date DATE NOT NULL,
    CONSTRAINT employees_pk PRIMARY KEY (emp_no)
);

-- ------------------------------------------------------------
-- Tabla: dept_emp
-- ------------------------------------------------------------
CREATE TABLE public.dept_emp (
    emp_no INTEGER NOT NULL,
    dept_no CHAR(4) NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    CONSTRAINT dept_emp_pk PRIMARY KEY (emp_no, dept_no),
    CONSTRAINT dept_emp_emp_no_fkey FOREIGN KEY (emp_no) REFERENCES public.employees (emp_no),
    CONSTRAINT dept_emp_dept_no_fkey FOREIGN KEY (dept_no) REFERENCES public.departments (dept_no)
);

-- ------------------------------------------------------------
-- Tabla: dept_manager
-- ------------------------------------------------------------
CREATE TABLE public.dept_manager (
    emp_no INTEGER NOT NULL,
    dept_no CHAR(4) NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    CONSTRAINT dept_manager_pk PRIMARY KEY (emp_no, dept_no),
    CONSTRAINT dept_manager_emp_no_fkey FOREIGN KEY (emp_no) REFERENCES public.employees (emp_no),
    CONSTRAINT dept_manager_dept_no_fkey FOREIGN KEY (dept_no) REFERENCES public.departments (dept_no)
);

-- ------------------------------------------------------------
-- Tabla: salaries
-- ------------------------------------------------------------
CREATE TABLE public.salaries (
    emp_no INTEGER NOT NULL,
    salary INTEGER NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    CONSTRAINT salaries_pk PRIMARY KEY (emp_no, from_date),
    CONSTRAINT salaries_emp_no_fkey FOREIGN KEY (emp_no) REFERENCES public.employees (emp_no)
);

-- ------------------------------------------------------------
-- Tabla: titles
-- ------------------------------------------------------------
CREATE TABLE public.titles (
    emp_no INTEGER NOT NULL,
    title VARCHAR(50) NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE,
    CONSTRAINT titles_pk PRIMARY KEY (emp_no, title, from_date),
    CONSTRAINT titles_emp_no_fkey FOREIGN KEY (emp_no) REFERENCES public.employees (emp_no)
);

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
