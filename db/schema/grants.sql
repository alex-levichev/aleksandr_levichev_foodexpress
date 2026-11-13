DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'inspector'
    ) THEN
        CREATE ROLE inspector
        WITH LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END;
$$;

REVOKE ALL PRIVILEGES
ON SCHEMA levichev_food FROM inspector;

GRANT USAGE
ON SCHEMA levichev_food TO inspector;

REVOKE ALL PRIVILEGES
ON ALL TABLES IN SCHEMA levichev_food
FROM inspector;

GRANT SELECT
ON ALL TABLES IN SCHEMA levichev_food
TO inspector;

REVOKE ALL PRIVILEGES
ON ALL SEQUENCES IN SCHEMA levichev_food
FROM inspector;

GRANT EXECUTE
ON ALL ROUTINES IN SCHEMA levichev_food
TO inspector;

GRANT USAGE
ON SCHEMA exts TO inspector;
