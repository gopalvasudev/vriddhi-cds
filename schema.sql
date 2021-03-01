CREATE SCHEMA admin
    CREATE TABLE users
    (
        id SERIAL PRIMARY KEY
       ,first_name VARCHAR(50) NOT NULL
       ,last_name VARCHAR(50) NOT NULL
       ,date_of_birth DATE
       ,address TEXT NOT NULL
       ,aadhaar_number INT CHECK (aadhaar_number <= 999999999999)
       ,pan CHAR(10)
       ,group_id INT
    );
    
    CREATE TABLE roles
    (
        id SERIAL PRIMARY KEY
       ,title VARCHAR(20) CHECK (title ~ '[A-Za-z_][A-Za-z0-9_]*')
       ,description TEXT
    );
    
    CREATE TABLE user_role
    (
        user_id INT REFERENCES users(id)
       ,role_id INT REFERENCES roles(id)
    );
    
    CREATE TABLE agent
    (
        user_id REFERENCES users(id)
    );
    
    CREATE TABLE staff
    (
        user_id REFERENCES users(id)
    );
    
    CREATE TABLE members
    (
        user_id REFERENCES users(id)
    );
    
    CREATE TABLE residence_verifier
    (
        user_id REFERENCES users(id)
    );
    
    CREATE TABLE group_leader
    (
        user_id REFERENCES users(id)
    );
    
    CREATE TABLE center_leader
    (
        user_id REFERENCES users(id)
    );
    
    CREATE TABLE field_officer
    (
        user_id REFERENCES users(id)
       ,branch_id
    );
    
    
    CREATE OR REPLACE FUNCTION create_user_role()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS
    $$
    DECLARE
        role_title text;
        new_table text;
    BEGIN
        SELECT title
        INTO role_title
        FROM admin.roles as R

        WHERE R.id = NEW.id
        ;

        SELECT 'admin.' || role_title INTO new_table;
        EXECUTE format('CREATE TABLE %s (
                        id INTEGER REFERENCES admin.users (id)
                            ON DELETE CASCADE,
                        PRIMARY KEY (id)
                        );
                       '
                        ,new_table
                       );
    RETURN NULL;
    END;
    $$
    ;
    
    
    CREATE OR REPLACE FUNCTION admin.insert_user_role()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS
    $$
    DECLARE
        role_title text;
        ins_table text;
    BEGIN
        SELECT title
        INTO role_title
        FROM admin.roles as R

        WHERE R.id = NEW.role
        ;
        SELECT 'admin.' || role_title INTO ins_table;
        EXECUTE format('INSERT INTO %s (id) VALUES (%s)'
                        ,ins_table, NEW.user_id
                       );
    RETURN NULL;
    END;
    $$
    ;
 
 
    CREATE OR REPLACE FUNCTION admin.delete_user_role()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS
    $$
    DECLARE
        role_title TEXT;
        del_table TEXT;
        geo_locale TEXT;
        num_responsibilities INT;
        TYPE leaders IS TABLE OF VARCHAR(50);
        leader_types := leaders('admin.group_leader', 'admin.center_leader');
    BEGIN
        SELECT R.title
        INTO role_title
        FROM admin.roles as R

        WHERE R.id = OLD.role
        ;
        
        SELECT 'admin.' || role_title INTO del_table;
        
        IF del_table MEMBER OF leader_types THEN
            IF del_table = 'admin.group_leader' THEN
                geo_locale := 'groups';
            ELSIF del_table = 'admin.center_leader' THEN
                geo_locale := 'centers';
            END IF;
            
            EXECUTE format ('SELECT COUNT(*)
                             INTO num_responsibilities
                             FROM config.%s
                             WHERE leader_id = %s
                            '
                            ,geo_locale
                            ,OLD.user_id
                            )
            IF num_responsibilities > 1 THEN
                raise_application_error(-1, 'Cannot remove this user from this role as they have outstanding responsibilities');
            END IF;
        
        END IF;
        
        EXECUTE format('DELETE FROM %s WHERE id = %s'
                        ,del_table, OLD.user_id
                       );
    RETURN NULL;
    END;
    $$
;


CREATE SCHEMA config

    CREATE TABLE product_types
    (
        id  SERIAL PRIMARY KEY
       ,name VARCHAR(100)
    );
    
    
    CREATE TABLE product_property
    (
        type_id INT REFERENCES
       ,measurement_name VARCHAR(50)
    );
    
    
    CREATE TABLE branches
    (
        id SERIAL PRIMARY KEY
       ,name VARCHAR(50)
       ,location TEXT
    );
    
    
    CREATE TABLE communities
    (
        id SERIAL PRIMARY KEY
       ,name VARCHAR(50)
       ,field_officer_id INT REFERENCES admin.field_officer(id)
       ,location TEXT
    );
    
    
    CREATE TABLE centers
    (
        id SERIAL PRIMARY KEY
       ,name VARCHAR(50)
       ,community_id INT REFERENCES communities(id)
       ,leader_id INT REFERENCES
       ,location TEXT
    );
    
    
    CREATE TABLE groups
    (
        id SERIAL PRIMARY KEY
       ,name VARCHAR(50)
       ,center_id INT REFERENCES communities(id)
       ,leader_id INT REFERENCES
       ,location TEXT
    );


ALTER TABLE admin.users
    ADD CONSTRAINT fkey_group_id
        FOREIGN KEY group_id
        REFERENCES config.groups(id)
;


ALTER TABLE admin.field_officer
    ADD CONSTRAINT fkey_branch_id
    FOREIGN KEY branch_id
    REFERENCES config.branches(id)
;


CREATE SCHEMA partners

    CREATE TABLE partners
    (
        id SERIAL PRIMARY KEY
       ,name VARCHAR(50)
       ,measurement_name VARCHAR(20)
       ,measurement_value jsonb
    );
    
    
    CREATE TABLE products
    (
        id SERIAL PRIMARY KEY
       ,name VARCHAR(50)
       ,measurement_name VARCHAR(20)
       ,measurement_value jsonb
    );
    
    
    CREATE TABLE partner_product
    (
        partner_id INT REFERENCES partners(id)
       ,product_id INT REFERENCES products(id)
       
       ,PRIMARY KEY (partner_id, product_id)
    );


CREATE SCHEMA objects    

    CREATE TABLE providers
    (
        id SERIAL PRIMARY KEY,
       ,name varchar(100)    
    );


    CREATE TABLE products
    (
        id SERIAL PRIMARY KEY
       ,name VARCHAR(100),
       ,provider_id REFERENCES objects.providers(id)
       ,type_id REFERENCES config.product_types(id)
    );
    
    
    CREATE TABLE accounts
    (
        id SERIAL PRIMARY KEY
       ,member_id INT REFERENCES admin.members(id)
       ,product_id INT REFERENCES products(id)
       ,start_date DATE
       ,end_date DATE
       ,collateral TEXT
    );
    
    
    CREATE TABLE account_backers
    (
        account_id INT REFERENCES accounts(id)
       ,partner_id INT REFERENCES partners.partner_product(partner_id)
       ,product_id INT REFERENCES partners.partner_product(p_id)
       
       ,PRIMARY KEY (account_id, partner_id, product_id)
    );
    
    
    CREATE TABLE account_guarantor
    (
        user_id INT REFERENCES admin.users(id)  -- TODO: does this have to be a member/user/staff/...?
       ,account_id INT REFERENCES accountsI(id)
    );


    CREATE TABLE prepaid_cards
    (
        card_number VARCHAR(50) PRIMARY KEY
       ,account_id INT REFERENCES
       ,member_id INT REFERENCES admin.members(id)
       ,date_of_purchase DATE NOT NULL
       ,date_of_activation DATE
       ,date_of_cancelation DATE
       ,date_of_expiry DATE
    );
    
    
    CREATE TABLE gold_packets  -- TODO: can this change? what if the member wants to add more gold to this?
    (
        id SERIAL PRIMARY KEY
       ,member_id INT REFERENCES admin.members(id)
       ,value INT 
            NOT NULL 
            CHECK (value > 0)
       ,appraisal TEXT
       ,custodian_id INT REFERENCES admin.staff(id)
       ,branch_id INT REFERENCES config.branches(id)
       ,date_received DATE NOT NULL
       ,date_returned DATE
    );
    
    
CREATE SCHEMA update
    CREATE TABLE updates
    (
        id SERIAL PRIMARY KEY
       ,conductor_id INT REFERENCES admin.staff(id)
       ,start_time TIMESTAMP 
            NOT NULL
            DEFAULT CURRENT_TIMESTAMP
       ,end_time TIMESTAMP
    );
    

    CREATE TABLE prepaid_card
    (
        update_id INT REFERENCES updates(id)
       ,card_number VARCHAR(50) REFERENCES objects.prepaid_cards(card_number)
       ,member_id INT REFERENCES admin.members(id)
       ,account_id INT REFERENCES objects.accounts(id)
       ,measurement_time TIMESTAMP
            NOT NULL
            DEFAULT CURRENT_TIMESTAMP
       ,date_of_cancelation DATE
       
       ,PRIMARY KEY (update_id, card_number)
    );
    
    
    CREATE TABLE account
    (
        update_id INT REFERENCES updates(id)
       ,account_id INT REFERENCES objects.accounts(id)
       ,measurement_name VARCHAR(50)
       ,measurement_value jsonb
       ,measurement_time
            NOT NULL
            DEFAULT CURRENT_TIMESTAMP
       
       ,PRIMARY KEY(update_id, account_id, measurement_name)
    );
    
    
    CREATE TABLE centers
    (
        update_id INT REFERENCES updates(id)
       ,center_id INT REFERENCES config.centers(id)
       ,leader_id INT REFERENCES admin.center_leader(id)
       ,measurement_time TIMESTAMP
            NOT NULL
            DEFAULT CURRENT_TIMESTAMP
    );
    
    
    CREATE TABLE groups
    (
        update_id INT REFERENCES updates(id)
       ,group_id INT REFERENCES config.groups(id)
       ,leader_id INT REFERENCES admin.center_leader(id)
       ,measurement_time TIMESTAMP
            NOT NULL
            DEFAULT CURRENT_TIMESTAMP
    );
 
 
-- triggers

CREATE TRIGGER create_user_role
    AFTER INSERT ON admin.roles
    FOR EACH ROW
        EXECUTE PROCEDURE admin.create_user_role()
;


CREATE TRIGGER create_user_role
    AFTER INSERT ON admin.user_role
    FOR EACH ROW
        EXECUTE PROCEDURE admin.insert_user_role()
;


CREATE TRIGGER delete_user_role
    BEFORE DELETE ON admin.user_role
    FOR EACH ROW
        EXECUTE PROCEDURE admin.delete_user_role()
;