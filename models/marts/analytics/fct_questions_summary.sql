-- Fact table: Questions summary metrics
-- This aggregates question data for analytics

{{ config(
    materialized='table'
) }}

WITH questions AS (
    SELECT * FROM {{ ref('stg_stackoverflow__questions') }}
),

daily_metrics AS (
    SELECT
        DATE(created_at) AS question_date,
        COUNT(*) AS total_questions,
        SUM(CASE WHEN has_accepted_answer THEN 1 ELSE 0 END) AS questions_with_accepted_answer,
        AVG(score) AS avg_score,
        SUM(view_count) AS total_views,
        AVG(answer_count) AS avg_answers_per_question,
        
        -- Score distribution
        SUM(CASE WHEN score_category = 'high' THEN 1 ELSE 0 END) AS high_score_questions,
        SUM(CASE WHEN score_category = 'medium' THEN 1 ELSE 0 END) AS medium_score_questions,
        SUM(CASE WHEN score_category = 'neutral' THEN 1 ELSE 0 END) AS neutral_score_questions,
        SUM(CASE WHEN score_category = 'negative' THEN 1 ELSE 0 END) AS negative_score_questions
        
    FROM questions
    GROUP BY DATE(created_at)
)

SELECT
    question_date,
    total_questions,
    questions_with_accepted_answer,
    ROUND(SAFE_DIVIDE(questions_with_accepted_answer, total_questions) * 100, 2) AS acceptance_rate_pct,
    ROUND(avg_score, 2) AS avg_score,
    total_views,
    ROUND(avg_answers_per_question, 2) AS avg_answers_per_question,
    high_score_questions,
    medium_score_questions,
    neutral_score_questions,
    negative_score_questions
    
FROM daily_metrics
ORDER BY question_date DESC
