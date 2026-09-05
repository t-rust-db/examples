-- 4-table JOIN: every movie with its director and lead cast, ordered by year.
SELECT movies.year, movies.title, directors.name, actors.name, movie_cast.role
FROM movies
JOIN directors ON movies.director_id = directors.id
JOIN movie_cast ON movie_cast.movie_id = movies.id
JOIN actors ON actors.id = movie_cast.actor_id
WHERE movie_cast.is_lead = 1
ORDER BY movies.year
