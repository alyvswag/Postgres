create table "bank_customer_schema".customer
(
    id         serial primary key,
    is_active  boolean      not null default true,
    name       varchar(100) not null,
    surname    varchar(100) not null,
    birth_date date         not null,
    fin        varchar(7)   not null unique,
    created_at timestamp    not null default now(),
    updated_at timestamp
);
create table "bank_customer_schema".customer_phone
(
    id           serial primary key,
    customer_id  bigint references "bank_customer_schema".customer (id),
    phone_number varchar(20) not null,
    is_active    boolean     not null default true,
    created_at   timestamp   not null default now(),
    updated_at   timestamp
);
create table "bank_customer_schema".card
(
    id          serial primary key,
    customer_id bigint references "bank_customer_schema".customer (id),
    status      varchar(20) not null default 'ACTIVE',
    card_number varchar(16) not null unique,
    exp_date    date        not null,
    cvv         varchar(3)  not null,
    ccy         varchar(5)  not null,
    amount      decimal(15, 2),
    created_at  timestamp   not null default now(),
    updated_at  timestamp
);
create table "bank_customer_schema".transactions
(
    id         serial primary key,
    sender     bigint      not null,
    receiver   varchar(16) not null,
    ccy        varchar(5)  not null,
    amount     decimal,
    created_at timestamp   not null default now(),
    updated_at timestamp
);

ALTER TABLE bank_customer_schema.transactions
    ADD CONSTRAINT sender
        FOREIGN KEY (sender) REFERENCES bank_customer_schema.card (id);


ALTER TABLE bank_customer_schema.transactions
    ALTER COLUMN sender TYPE BIGINT
        USING sender::BIGINT;

create table "bank_customer_schema".profile
(
    id          serial primary key,
    customer_id bigint references "bank_customer_schema".customer (id),
    username    varchar(15) not null unique,
    password    varchar(15) not null,
    is_active   boolean     not null default true,
    created_at  timestamp   not null default now(),
    updated_at  timestamp
);

insert into bank_customer_schema.card(customer_id, card_number, exp_date, cvv, ccy, amount)
VALUES (1, '4098584492961501', '2027-01-02', '123', 'AZN', 400),
       (1, '5239151799612190', '2030-04-02', '330', 'AZN', 1000),
       (2, '4098584478351600', '2029-01-10', '001', 'AZN', 2300),
       (2, '5239151799781234', '2024-10-02', '490', 'AZN', 5000),
       (3, '4098584490807635', '2025-12-20', '101', 'AZN', 550),
       (4, '4098584412344321', '2028-01-25', '301', 'AZN', 900),
       (6, '4098584478453212', '2029-05-26', '836', 'AZN', 100);

--1
select c.card_number, cus.name, cus.surname, c.amount, c.ccy
from bank_customer_schema.customer cus
         right join bank_customer_schema.card c on cus.id = c.customer_id;
--2
create or replace procedure bank_customer_schema.addCustomer(
    nameP varchar(100),
    surnameP varchar(100),
    birth_dateP date,
    finP varchar(100)
)
    language plpgsql
as
$$
begin
    insert into bank_customer_schema.customer(name, surname, birth_date, fin)
    values (nameP, surnameP, birth_dateP, finP);

    commit;
end;
$$;
call bank_customer_schema.addCustomer('Osman', 'Nezerli', '2005-06-01', 'hgyufw3');
--3
create or replace procedure bank_customer_schema.deleteCustomer(
    idP bigint
)
    language plpgsql
as
$$
begin
    update bank_customer_schema.customer c
    set is_active = false
    where c.id = idP;

end;
$$;
call bank_customer_schema.deleteCustomer(7);
--4
create or replace procedure bank_customer_schema.blockedCard(
    idP bigint
)
    language plpgsql
as
$$
begin
    update bank_customer_schema.card c
    set status = 'INACTIVE'
    where id = idP;
end;
$$;
call bank_customer_schema.blockedCard(1);
--5
create or replace procedure bank_customer_schema.addCard(
    customer_idP bigint,
    card_numberP varchar(16),
    exp_dateP date,
    cvvP varchar(3),
    ccyP varchar(5),
    amountP dec
)
    language plpgsql
as
$$
begin
    insert into bank_customer_schema.card(customer_id, card_number, exp_date, cvv, ccy, amount)
    values (customer_idP, card_numberP, exp_dateP, cvvP, ccyP, amountP);
    commit;
end;
$$;
call bank_customer_schema.addCard(7, '5239151788990012', '2029-11-11', '498', 'AZN', 9000);
--6
select c.card_number, t.receiver, t.amount, t.created_at
from bank_customer_schema.transactions t
         inner join bank_customer_schema.card c on t.sender = c.id;
--7
select cus.name, c.card_number, c.amount, c.ccy
from bank_customer_schema.customer cus
         right join bank_customer_schema.card c on cus.id = c.customer_id
where cus.id = 5;
--8
CREATE OR REPLACE PROCEDURE bank_customer_schema.transferMoneyCard(
    receiverP VARCHAR(16),
    senderP bigint,
    amountP DECIMAL
)
    LANGUAGE plpgsql
AS
$$
DECLARE
    sender_card_number_prefix VARCHAR(4);
    sender_balance            DECIMAL;
    ccyP                      varchar(5);
BEGIN

    SELECT SUBSTRING(card_number FROM 1 FOR 4), amount, ccy
    INTO sender_card_number_prefix, sender_balance,ccyP
    FROM bank_customer_schema.card
    WHERE id = senderP;

    IF amountP > sender_balance THEN
        RAISE EXCEPTION 'Balans yoxdur';
        RETURN;
    END IF;

    UPDATE bank_customer_schema.card
    SET amount = amount - amountP
    WHERE id = senderP;

    UPDATE bank_customer_schema.card
    SET amount = amount + amountP
    WHERE card_number = receiverP;

    IF SUBSTRING(receiverP, 1, 4) != sender_card_number_prefix THEN
        UPDATE bank_customer_schema.card
        set amount = amount - (amountP * 1.05)
        where id = senderP;
    END IF;

    insert into bank_customer_schema.transactions(sender, receiver, ccy, amount)
    VALUES (senderP, receiverP, ccyP, amountP);

END;
$$;
call bank_customer_schema.transferMoneyCard('4098584492961501', 2, 100);
--9
create or replace procedure bank_customer_schema.transferMoneyPhoneNumber(
    receiverP VARCHAR(16),
    senderP bigint,
    amountP DECIMAL
)
    language plpgsql
as
$$
declare
    sender_balance decimal;
    ccyP           varchar(5);
begin

    select amount, ccy
    into sender_balance,ccyp
    from bank_customer_schema.card
    where id = senderP;

    IF amountP > sender_balance THEN
        RAISE EXCEPTION 'Balans yoxdur';
        RETURN;
    END IF;

    update bank_customer_schema.card
    set amount = amount - amountP
    where id = senderP;

    insert into bank_customer_schema.transactions(sender, receiver, ccy, amount)
    VALUES (senderP, receiverP, ccyP, amountP);
end;
$$;
call bank_customer_schema.transfermoneyphonenumber('0504946219', 7, 45)

















