-- Diana's Question: Who had the highest PPG in away games this week?
SELECT p.name, ROUND(AVG(ps.points)::numeric, 1) AS ppg
FROM player_stats ps
JOIN players p ON ps.player_id = p.player_id
JOIN games g ON ps.game_id = g.game_id
WHERE g.away_team_id = p.team_id
GROUP BY p.name
ORDER BY ppg DESC;
