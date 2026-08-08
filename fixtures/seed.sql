-- Lorem ipsum SQLite test database for zig-sqlite-compare
-- Schema mirrors typical Kilo-style tables (session, project, message)
-- but populated with synthetic lorem ipsum data only.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE project (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    directory   TEXT NOT NULL,
    created_at  INTEGER NOT NULL
);

CREATE TABLE session (
    id          TEXT PRIMARY KEY,
    project_id  TEXT NOT NULL REFERENCES project(id),
    slug        TEXT NOT NULL,
    title       TEXT NOT NULL,
    created_at  INTEGER NOT NULL,
    FOREIGN KEY (project_id) REFERENCES project(id)
);

CREATE TABLE message (
    id          INTEGER PRIMARY KEY,
    session_id  TEXT NOT NULL REFERENCES session(id),
    role        TEXT NOT NULL,
    content     TEXT NOT NULL,
    created_at  INTEGER NOT NULL
);

-- Projects (3 entries — matches Kilo-like minimal layout)
INSERT INTO project VALUES
    ('prj_lorem_001', 'Lorem Ipsum Dolor',          '/tmp/lorem/project-a', 1700000000000),
    ('prj_lorem_002', 'Sit Amet Consectetur',        '/tmp/lorem/project-b', 1700000100000),
    ('prj_lorem_003', 'Adipiscing Elit Sed Do',     '/tmp/lorem/project-c', 1700000200000);

-- Sessions (5 entries — matches the comparison query LIMIT 5)
INSERT INTO session VALUES
    ('ses_lorem_001', 'prj_lorem_001', 'happy-tigers',   'Lorem ipsum dolor sit amet',                 1700001000000),
    ('ses_lorem_002', 'prj_lorem_001', 'silent-forest',  'Consectetur adipiscing elit sed do eiusmod', 1700002000000),
    ('ses_lorem_003', 'prj_lorem_002', 'quick-lagoon',   'Tempor incididunt ut labore et dolore',      1700003000000),
    ('ses_lorem_004', 'prj_lorem_002', 'misty-mountain', 'Magna aliqua ut enim ad minim veniam',       1700004000000),
    ('ses_lorem_005', 'prj_lorem_003', 'jolly-wizard',   'Quis nostrud exercitation ullamco laboris',  1700005000000);

-- Messages (a handful per session — enough to exercise basic query patterns)
INSERT INTO message VALUES
    (1, 'ses_lorem_001', 'user',      'Lorem ipsum dolor sit amet, consectetur adipiscing elit.', 1700001100000),
    (2, 'ses_lorem_001', 'assistant', 'Sed do eiusmod tempor incididunt ut labore et dolore magna.', 1700001200000),
    (3, 'ses_lorem_002', 'user',      'Ut enim ad minim veniam, quis nostrud exercitation.', 1700002100000),
    (4, 'ses_lorem_003', 'user',      'Duis aute irure dolor in reprehenderit in voluptate.', 1700003100000),
    (5, 'ses_lorem_003', 'assistant', 'Velit esse cillum dolore eu fugiat nulla pariatur.', 1700003200000),
    (6, 'ses_lorem_004', 'user',      'Excepteur sint occaecat cupidatat non proident.', 1700004100000),
    (7, 'ses_lorem_005', 'user',      'Sunt in culpa qui officia deserunt mollit anim.', 1700005100000),
    (8, 'ses_lorem_005', 'assistant', 'At vero eos et accusamus et iusto odio dignissimos.', 1700005200000);