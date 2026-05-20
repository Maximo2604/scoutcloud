-- Teams
CREATE TABLE IF NOT EXISTS teams (
  team_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  conference VARCHAR(20),
  division VARCHAR(20)
);

-- Players
CREATE TABLE IF NOT EXISTS players (
  player_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  team_id INTEGER REFERENCES teams(team_id),
  position VARCHAR(50),
  nationality VARCHAR(50)
);

-- Games
CREATE TABLE IF NOT EXISTS games (
  game_id SERIAL PRIMARY KEY,
  home_team_id INTEGER REFERENCES teams(team_id),
  away_team_id INTEGER REFERENCES teams(team_id),
  game_date DATE NOT NULL,
  home_score INTEGER,
  away_score INTEGER
);

-- Player Stats
CREATE TABLE IF NOT EXISTS player_stats (
  stat_id SERIAL PRIMARY KEY,
  player_id INTEGER REFERENCES players(player_id),
  game_id INTEGER REFERENCES games(game_id),
  points INTEGER,
  assists INTEGER,
  rebounds INTEGER
);

-- Seed teams
INSERT INTO teams (name, conference, division)
VALUES ('New York Knicks', 'Eastern', 'Atlantic'),
       ('Boston Celtics', 'Eastern', 'Atlantic'),
       ('Los Angeles Lakers', 'Western', 'Pacific'),
       ('Golden State Warriors', 'Western', 'Pacific');

-- Seed players
INSERT INTO players (name, team_id, position, nationality)
VALUES ('Jalen Brunson', 1, 'Guard', 'American'),
       ('Jayson Tatum', 2, 'Forward', 'American'),
       ('LeBron James', 3, 'Forward', 'American'),
       ('Stephen Curry', 4, 'Guard', 'American');

-- Seed games
INSERT INTO games (home_team_id, away_team_id, game_date, home_score, away_score)
VALUES (1, 2, '2026-05-14', 108, 112),
       (3, 4, '2026-05-15', 94, 101),
       (2, 3, '2026-05-16', 115, 110);

-- Seed player stats
INSERT INTO player_stats (player_id, game_id, points, assists, rebounds)
VALUES (1, 1, 31, 8, 4),
       (2, 1, 28, 5, 9),
       (3, 2, 27, 7, 8),
       (4, 2, 33, 6, 5),
       (2, 3, 24, 4, 7),
       (3, 3, 29, 8, 9);
