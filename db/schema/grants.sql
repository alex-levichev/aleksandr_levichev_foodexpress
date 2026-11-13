-- FOOD-109: пользователь inspector и права доступа

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

GRANT ALL PRIVILEGES
ON SCHEMA levichev_food TO inspector;

GRANT ALL PRIVILEGES
ON ALL TABLES IN SCHEMA levichev_food TO inspector;

GRANT ALL PRIVILEGES
ON ALL SEQUENCES IN SCHEMA levichev_food TO inspector;

GRANT EXECUTE
ON ALL ROUTINES IN SCHEMA levichev_food TO inspector;

GRANT USAGE
ON SCHEMA exts TO inspector;