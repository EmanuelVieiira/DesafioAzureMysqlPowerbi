-- ============================================================
-- Desafio Azure MySQL + Power BI
-- Script de criação do schema e das tabelas
-- ============================================================

CREATE SCHEMA IF NOT EXISTS azure_company;
USE azure_company;

-- ------------------------------------------------------------
-- Tabela: employee
-- ------------------------------------------------------------
CREATE TABLE employee(
    Fname varchar(15) not null,
    Minit char,
    Lname varchar(15) not null,
    Ssn char(9) not null,
    Bdate date,
    Address varchar(30),
    Sex char,
    Salary decimal(10,2),
    Super_ssn char(9),
    Dno int not null,
    constraint chk_salary_employee check (Salary > 2000.0),
    constraint pk_employee primary key (Ssn)
);

-- Auto-referência: um colaborador pode ter outro colaborador como gerente
ALTER TABLE employee
    ADD CONSTRAINT fk_employee
    FOREIGN KEY (Super_ssn) REFERENCES employee(Ssn)
    ON DELETE SET NULL
    ON UPDATE CASCADE;

ALTER TABLE employee
    MODIFY Dno int not null default 1;

-- ------------------------------------------------------------
-- Tabela: departament
-- ------------------------------------------------------------
CREATE TABLE departament(
    Dname varchar(15) not null,
    Dnumber int not null,
    Mgr_ssn char(9) not null,
    Mgr_start_date date,
    Dept_create_date date,
    constraint chk_date_dept check (Dept_create_date < Mgr_start_date),
    constraint pk_dept primary key (Dnumber),
    constraint unique_name_dept unique (Dname),
    foreign key (Mgr_ssn) references employee(Ssn)
);

-- Substitui a FK padrão gerada automaticamente por uma nomeada,
-- com regra de atualização em cascata
ALTER TABLE departament
    ADD CONSTRAINT fk_dept
    FOREIGN KEY (Mgr_ssn) REFERENCES employee(Ssn)
    ON UPDATE CASCADE;

-- ------------------------------------------------------------
-- Tabela: dept_locations
-- ------------------------------------------------------------
CREATE TABLE dept_locations(
    Dnumber int not null,
    Dlocation varchar(15) not null,
    constraint pk_dept_locations primary key (Dnumber, Dlocation),
    constraint fk_dept_locations foreign key (Dnumber) references departament(Dnumber)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- ------------------------------------------------------------
-- Tabela: project
-- ------------------------------------------------------------
CREATE TABLE project(
    Pname varchar(15) not null,
    Pnumber int not null,
    Plocation varchar(15),
    Dnum int not null,
    primary key (Pnumber),
    constraint unique_project unique (Pname),
    constraint fk_project foreign key (Dnum) references departament(Dnumber)
);

-- ------------------------------------------------------------
-- Tabela: works_on
-- ------------------------------------------------------------
CREATE TABLE works_on(
    Essn char(9) not null,
    Pno int not null,
    Hours decimal(3,1) not null,
    primary key (Essn, Pno),
    constraint fk_employee_works_on foreign key (Essn) references employee(Ssn),
    constraint fk_project_works_on foreign key (Pno) references project(Pnumber)
);

-- ------------------------------------------------------------
-- Tabela: dependent
-- ------------------------------------------------------------
CREATE TABLE dependent(
    Essn char(9) not null,
    Dependent_name varchar(15) not null,
    Sex char,
    Bdate date,
    Relationship varchar(8),
    primary key (Essn, Dependent_name),
    constraint fk_dependent foreign key (Essn) references employee(Ssn)
);
