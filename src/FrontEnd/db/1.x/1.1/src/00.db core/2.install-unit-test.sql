/********************************************************************************
The PostgreSQL License

Copyright (c) 2014, Binod Nepal, Mix Open Foundation (http://mixof.org).

Permission to use, copy, modify, and distribute this software and its documentation 
for any purpose, without fee, and without a written agreement is hereby granted, 
provided that the above copyright notice and this paragraph and 
the following two paragraphs appear in all copies.

IN NO EVENT SHALL MIX OPEN FOUNDATION BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, 
SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, 
ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF 
MIX OPEN FOUNDATION HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

MIX OPEN FOUNDATION SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, 
BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, 
AND MIX OPEN FOUNDATION HAS NO OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, 
UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
***********************************************************************************/

DROP SCHEMA IF EXISTS assert CASCADE;
DROP SCHEMA IF EXISTS unit_tests CASCADE;
DROP DOMAIN IF EXISTS public.test_result CASCADE;

CREATE SCHEMA assert AUTHORIZATION postgres;
CREATE SCHEMA unit_tests AUTHORIZATION postgres;
CREATE DOMAIN public.test_result AS text;

CREATE TABLE unit_tests.tests
(
    test_id                                 SERIAL NOT NULL PRIMARY KEY,
    started_on                              TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT(CURRENT_TIMESTAMP AT TIME ZONE 'UTC'),
    completed_on                            TIMESTAMP WITHOUT TIME ZONE NULL,
    total_tests                             integer NULL DEFAULT(0),
    failed_tests                            integer NULL DEFAULT(0)
);

CREATE INDEX unit_tests_tests_started_on_inx
ON unit_tests.tests(started_on);

CREATE INDEX unit_tests_tests_completed_on_inx
ON unit_tests.tests(completed_on);

CREATE INDEX unit_tests_tests_failed_tests_inx
ON unit_tests.tests(failed_tests);

CREATE TABLE unit_tests.test_details
(
    id                                      BIGSERIAL NOT NULL PRIMARY KEY,
    test_id                                 integer NOT NULL REFERENCES unit_tests.tests(test_id),
    function_name                           text NOT NULL,
    message                                 text NOT NULL,
    ts                                      TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT(CURRENT_TIMESTAMP AT TIME ZONE 'UTC'),
    status                                  boolean NOT NULL
);

CREATE INDEX unit_tests_test_details_test_id_inx
ON unit_tests.test_details(test_id);

CREATE INDEX unit_tests_test_details_status_inx
ON unit_tests.test_details(status);

CREATE FUNCTION assert.fail(message text)
RETURNS text
AS
$$
BEGIN
    IF $1 IS NULL OR trim($1) = '' THEN
        message := 'NO REASON SPECIFIED';
    END IF;
    
    RAISE WARNING 'ASSERT FAILED : %', message;
    RETURN message;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;

CREATE FUNCTION assert.pass(message text)
RETURNS text
AS
$$
BEGIN
    RAISE NOTICE 'ASSERT PASSED : %', message;
    RETURN '';
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;

CREATE FUNCTION assert.ok(message text)
RETURNS text
AS
$$
BEGIN
    RAISE NOTICE 'OK : %', message;
    RETURN '';
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;

CREATE FUNCTION assert.is_equal(IN have anyelement, IN want anyelement, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF($1 = $2) THEN
        message := 'Assert is equal.';
        PERFORM assert.ok(message);
        result := true;
        RETURN;
    END IF;

    message := E'ASSERT IS_EQUAL FAILED.\n\nHave -> ' || $1::text || E'\nWant -> ' || $2::text || E'\n';    
    PERFORM assert.fail(message);
    result := false;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;


CREATE FUNCTION assert.are_equal(VARIADIC anyarray, OUT message text, OUT result boolean)
AS
$$
    DECLARE count integer=0;
BEGIN
    SELECT COUNT(DISTINCT $1[s.i]) INTO count
    FROM generate_series(array_lower($1,1), array_upper($1,1)) AS s(i)
    ORDER BY 1;

    IF count <> 1 THEN
        MESSAGE := 'ASSERT ARE_EQUAL FAILED.';  
        PERFORM assert.fail(MESSAGE);
        RESULT := FALSE;
        RETURN;
    END IF;

    message := 'Asserts are equal.';
    PERFORM assert.ok(message);
    result := true;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;

CREATE FUNCTION assert.is_not_equal(IN already_have anyelement, IN dont_want anyelement, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF($1 != $2) THEN
        message := 'Assert is not equal.';
        PERFORM assert.ok(message);
        result := true;
        RETURN;
    END IF;
    
    message := E'ASSERT IS_NOT_EQUAL FAILED.\n\nAlready Have -> ' || $1::text || E'\nDon''t Want   -> ' || $2::text || E'\n';   
    PERFORM assert.fail(message);
    result := false;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;

CREATE FUNCTION assert.are_not_equal(VARIADIC anyarray, OUT message text, OUT result boolean)
AS
$$
    DECLARE count integer=0;
BEGIN
    SELECT COUNT(DISTINCT $1[s.i]) INTO count
    FROM generate_series(array_lower($1,1), array_upper($1,1)) AS s(i)
    ORDER BY 1;

    IF count <> array_upper($1,1) THEN
        MESSAGE := 'ASSERT ARE_NOT_EQUAL FAILED.';  
        PERFORM assert.fail(MESSAGE);
        RESULT := FALSE;
        RETURN;
    END IF;

    message := 'Asserts are not equal.';
    PERFORM assert.ok(message);
    result := true;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;


CREATE FUNCTION assert.is_null(IN anyelement, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF($1 IS NULL) THEN
        message := 'Assert is NULL.';
        PERFORM assert.ok(message);
        result := true;
        RETURN;
    END IF;
    
    message := E'ASSERT IS_NULL FAILED. NULL value was expected.\n\n\n';    
    PERFORM assert.fail(message);
    result := false;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;


CREATE FUNCTION assert.is_not_null(IN anyelement, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF($1 IS NOT NULL) THEN
        message := 'Assert is not NULL.';
        PERFORM assert.ok(message);
        result := true;
        RETURN;
    END IF;
    
    message := E'ASSERT IS_NOT_NULL FAILED. The value is NULL.\n\n\n';  
    PERFORM assert.fail(message);
    result := false;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;


CREATE FUNCTION assert.is_true(IN boolean, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF($1 == true) THEN
        message := 'Assert is true.';
        PERFORM assert.ok(message);
        result := true;
        RETURN;
    END IF;
    
    message := E'ASSERT IS_TRUE FAILED. A true condition was expected.\n\n\n';  
    PERFORM assert.fail(message);
    result := false;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;


CREATE FUNCTION assert.is_false(IN boolean, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF($1 == true) THEN
        message := 'Assert is false.';
        PERFORM assert.ok(message);
        result := true;
        RETURN;
    END IF;
    
    message := E'ASSERT IS_FALSE FAILED. A false condition was expected.\n\n\n';    
    PERFORM assert.fail(message);
    result := false;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;


CREATE FUNCTION assert.is_greater_than(IN x anyelement, IN y anyelement, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF($1 > $2) THEN
        message := 'Assert greater than condition is satisfied.';
        PERFORM assert.ok(message);
        result := true;
        RETURN;
    END IF;
    
    message := E'ASSERT IS_GREATER_THAN FAILED.\n\n X : -> ' || $1::text || E'\n is not greater than Y:   -> ' || $2::text || E'\n';    
    PERFORM assert.fail(message);
    result := false;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;


CREATE FUNCTION assert.is_less_than(IN x anyelement, IN y anyelement, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF($1 < $2) THEN
        message := 'Assert less than condition is satisfied.';
        PERFORM assert.ok(message);
        result := true;
        RETURN;
    END IF;
    
    message := E'ASSERT IS_LESS_THAN FAILED.\n\n X : -> ' || $1::text || E'\n is not  than Y:   -> ' || $2::text || E'\n';  
    PERFORM assert.fail(message);
    result := false;
    RETURN;
END
$$
LANGUAGE plpgsql
IMMUTABLE STRICT;


CREATE FUNCTION assert.function_exists(function_name text, OUT message text, OUT result boolean)
AS
$$
BEGIN
    IF NOT EXISTS
    (
        SELECT  1
        FROM    pg_catalog.pg_namespace n
        JOIN    pg_catalog.pg_proc p
        ON      pronamespace = n.oid
        WHERE replace(nspname || '.' || proname || '(' || oidvectortypes(proargtypes) || ')', ' ' , '')::text=$1
    ) THEN
        message := 'The function % does not exist.', $1;
        PERFORM assert.fail(message);

        result := false;
        RETURN;
    END IF;

    message := 'OK. The function ' || $1 || ' exists.';
    PERFORM assert.ok(message);
    result := true;
    RETURN;
END
$$
LANGUAGE plpgsql;



DROP FUNCTION IF EXISTS assert.if_functions_compile
(
    VARIADIC _schema_name text[],
    OUT message text, 
    OUT result boolean    
);

CREATE OR REPLACE FUNCTION assert.if_functions_compile
(
    VARIADIC _schema_name text[],
    OUT message text, 
    OUT result boolean
)
AS
$$
    DECLARE all_parameters              text;
    DECLARE current_function            RECORD;
    DECLARE current_function_name       text;
    DECLARE current_type                text;
    DECLARE current_type_schema         text;
    DECLARE current_parameter           text;
    DECLARE functions_count             smallint := 0;
    DECLARE current_parameters_count    int;
    DECLARE i                           int;
    DECLARE command_text                text;
    DECLARE failed_functions            text;
BEGIN
    FOR current_function IN 
        SELECT proname, proargtypes, nspname 
        FROM pg_proc 
        INNER JOIN pg_namespace 
        ON pg_proc.pronamespace = pg_namespace.oid 
        WHERE pronamespace IN 
        (
            SELECT oid FROM pg_namespace 
            WHERE nspname = ANY($1) 
            AND nspname NOT IN
            (
                'assert', 'unit_tests', 'information_schema'
            ) 
            AND proname NOT IN('if_functions_compile')
        ) 
    LOOP
        current_parameters_count := array_upper(current_function.proargtypes, 1) + 1;

        i := 0;
        all_parameters := '';

        LOOP
        IF i < current_parameters_count THEN
            IF i > 0 THEN
                all_parameters := all_parameters || ', ';
            END IF;

            SELECT 
                nspname, typname 
            INTO 
                current_type_schema, current_type 
            FROM pg_type 
            INNER JOIN pg_namespace 
            ON pg_type.typnamespace = pg_namespace.oid
            WHERE pg_type.oid = current_function.proargtypes[i];

            IF(current_type IN('int4', 'int8', 'numeric', 'integer_strict', 'money_strict','decimal_strict', 'integer_strict2', 'money_strict2','decimal_strict2', 'money','decimal', 'numeric', 'bigint')) THEN
                current_parameter := '1::' || current_type_schema || '.' || current_type;
            ELSIF(substring(current_type, 1, 1) = '_') THEN
                current_parameter := 'NULL::' || current_type_schema || '.' || substring(current_type, 2, length(current_type)) || '[]';
            ELSIF(current_type in ('date')) THEN            
                current_parameter := '''1-1-2000''::' || current_type;
            ELSIF(current_type = 'bool') THEN
                current_parameter := 'false';            
            ELSE
                current_parameter := '''''::' || quote_ident(current_type_schema) || '.' || quote_ident(current_type);
            END IF;
            
            all_parameters = all_parameters || current_parameter;

            i := i + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;

    BEGIN
        current_function_name := quote_ident(current_function.nspname)  || '.' || quote_ident(current_function.proname);
        command_text := 'SELECT * FROM ' || current_function_name || '(' || all_parameters || ');';

        EXECUTE command_text;
        functions_count := functions_count + 1;

        EXCEPTION WHEN OTHERS THEN
            IF(failed_functions IS NULL) THEN 
                failed_functions := '';
            END IF;

            IF(SQLSTATE IN('42702', '42704')) THEN
                failed_functions := failed_functions || E'\n' || command_text || E'\n' || SQLERRM || E'\n';                
            END IF;
    END;


    END LOOP;

    IF(failed_functions != '') THEN
        message := E'The test if_functions_compile failed. The following functions failed to compile : \n\n' || failed_functions;
        result := false;
        PERFORM assert.fail(message);
        RETURN;
    END IF;
END;
$$
LANGUAGE plpgsql 
VOLATILE;

DROP FUNCTION IF EXISTS assert.if_views_compile
(
    VARIADIC _schema_name text[],
    OUT message text, 
    OUT result boolean    
);

CREATE FUNCTION assert.if_views_compile
(
    VARIADIC _schema_name text[],
    OUT message text, 
    OUT result boolean    
)
AS
$$

    DECLARE message                     test_result;
    DECLARE current_view                RECORD;
    DECLARE current_view_name           text;
    DECLARE command_text                text;
    DECLARE failed_views                text;
BEGIN
    FOR current_view IN 
        SELECT table_name, table_schema 
        FROM information_schema.views
        WHERE table_schema = ANY($1) 
    LOOP

    BEGIN
        current_view_name := quote_ident(current_view.table_schema)  || '.' || quote_ident(current_view.table_name);
        command_text := 'SELECT * FROM ' || current_view_name || ' LIMIT 1;';

        RAISE NOTICE '%', command_text;
        
        EXECUTE command_text;

        EXCEPTION WHEN OTHERS THEN
            IF(failed_views IS NULL) THEN 
                failed_views := '';
            END IF;

            failed_views := failed_views || E'\n' || command_text || E'\n' || SQLERRM || E'\n';                
    END;


    END LOOP;

    IF(failed_views != '') THEN
        message := E'The test if_views_compile failed. The following views failed to compile : \n\n' || failed_views;
        result := false;
        PERFORM assert.fail(message);
        RETURN;
    END IF;

    RETURN;
END;
$$
LANGUAGE plpgsql 
VOLATILE;

CREATE FUNCTION unit_tests.begin(v int DEFAULT 9)
RETURNS TABLE(message text, result character(1))
AS
$$
    DECLARE this record;
    DECLARE _function_name text;
    DECLARE _sql text;
    DECLARE _message text;
    DECLARE _result character(1);
    DECLARE _test_id integer;
    DECLARE _status boolean;
    DECLARE _total_tests integer = 0;
    DECLARE _failed_tests integer = 0;
    DECLARE _list_of_failed_tests text;
    DECLARE _started_from TIMESTAMP WITHOUT TIME ZONE;
    DECLARE _completed_on TIMESTAMP WITHOUT TIME ZONE;
    DECLARE _delta integer;
    DECLARE _ret_val text = '';
    DECLARE _verbosity text[] = ARRAY['debug5', 'debug4', 'debug3', 'debug2', 'debug1', 'log', 'notice', 'warning', 'error', 'fatal', 'panic'];
BEGIN
    _started_from := clock_timestamp() AT TIME ZONE 'UTC';

    RAISE INFO 'Test started from : %', _started_from; 

    IF(v > 10) THEN
        v := 9;
    END IF;
    
    EXECUTE 'SET CLIENT_MIN_MESSAGES TO ' || _verbosity[v];

    RAISE WARNING 'CLIENT_MIN_MESSAGES set to : %' , _verbosity[v];
    

    SELECT nextval('unit_tests.tests_test_id_seq') INTO _test_id;

    INSERT INTO unit_tests.tests(test_id)
    SELECT _test_id;

    FOR this IN
        SELECT proname as function_name
        FROM    pg_catalog.pg_namespace n
        JOIN    pg_catalog.pg_proc p
        ON      pronamespace = n.oid
        WHERE   nspname = 'unit_tests'
        AND prorettype='test_result'::regtype::oid
    LOOP
        BEGIN
            _status := false;
            _total_tests := _total_tests + 1;
            
            _function_name = 'unit_tests.' || this.function_name || '()';
            _sql := 'SELECT ' || _function_name || ';';
            
            RAISE NOTICE 'RUNNING TEST : %.', _function_name;

            EXECUTE _sql INTO _message;

            IF _message = '' THEN
                _status := true;
            END IF;

            
            INSERT INTO unit_tests.test_details(test_id, function_name, message, status)
            SELECT _test_id, _function_name, _message, _status;

            IF NOT _status THEN
                _failed_tests := _failed_tests + 1;         
                RAISE WARNING 'TEST % FAILED.', _function_name;
                RAISE WARNING 'REASON: %', _message;
            ELSE
                RAISE NOTICE 'TEST % COMPLETED WITHOUT ERRORS.', _function_name;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            _message := 'ERR' || SQLSTATE || ': ' || SQLERRM;
            INSERT INTO unit_tests.test_details(test_id, function_name, message, status)
            SELECT _test_id, _function_name, _message, false;

            _failed_tests := _failed_tests + 1;         
            RAISE WARNING 'TEST % FAILED.', _function_name;
            RAISE WARNING 'REASON: %', _message;
        END;
    END LOOP;

    _completed_on := clock_timestamp() AT TIME ZONE 'UTC';
    _delta := extract(millisecond from _completed_on - _started_from)::integer;
    
    UPDATE unit_tests.tests
    SET total_tests = _total_tests, failed_tests = _failed_tests, completed_on = _completed_on
    WHERE test_id = _test_id;

    
    WITH failed_tests AS
    (
        SELECT row_number() over (order by id) AS id, 
        unit_tests.test_details.function_name,
        unit_tests.test_details.message
        FROM unit_tests.test_details 
        WHERE test_id = _test_id
        AND status= false
    )

    SELECT array_to_string(array_agg(f.id::text || '. ' || f.function_name || ' --> ' || f.message), E'\n') INTO _list_of_failed_tests 
    FROM failed_tests f;

    _ret_val := _ret_val ||  'Test completed on : ' || _completed_on::text || E' UTC. \nTotal test runtime: ' || _delta::text || E' ms.\n';
    _ret_val := _ret_val || E'\nTotal tests run : ' || COALESCE(_total_tests, '0')::text;
    _ret_val := _ret_val || E'.\nPassed tests    : ' || (COALESCE(_total_tests, '0') - COALESCE(_failed_tests, '0'))::text;
    _ret_val := _ret_val || E'.\nFailed tests    : ' || COALESCE(_failed_tests, '0')::text;
    _ret_val := _ret_val || E'.\n\nList of failed tests:\n' || '----------------------';
    _ret_val := _ret_val || E'\n' || COALESCE(_list_of_failed_tests, '<NULL>')::text;
    _ret_val := _ret_val || E'\n' || E'End of plpgunit test.\n\n';


    IF _failed_tests > 0 THEN
        _result := 'N';
        RAISE INFO '%', _ret_val;
    ELSE
        _result := 'Y';
        RAISE INFO '%', _ret_val;
    END IF;

    SET CLIENT_MIN_MESSAGES TO notice;

    RETURN QUERY SELECT _ret_val, _result;
END
$$
LANGUAGE plpgsql;


