-- [SPANNER] DDL generated from objects/project.proto
-- DO NOT EDIT — regenerate with: ./scripts/gen-schema.sh

-- NOTE: Spanner has no native enum type.
--       Enum columns use STRING(64) with a CHECK constraint.
-- NOTE: Spanner has no trigger support.
--       updated_at must be maintained by the application,
--       or use ALLOW_COMMIT_TIMESTAMP on a TIMESTAMP column.

-- ============================================================
-- Table: projects
-- ============================================================

CREATE TABLE projects (
    id STRING(64) NOT NULL,
    name STRING(255) NOT NULL,
    status STRING(64) NOT NULL,
    created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
    updated_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
    CONSTRAINT chk_projects_status CHECK (status IN ('active', 'terminated')),
) PRIMARY KEY (id);
