-- Аналіз динаміки доходів та користувачів
-- Розрахунок метрик доходу та поведінки користувачів
-- Підготовка даних для візуалізації у Tableau

with table_1 as (
    select
        date(date_trunc('month', payment_date)) as payment_month,
        user_id,
        sum(revenue_amount_usd) as total_revenue
    from project.games_payments gp
    group by 1, 2
),

table_2 as (
    select
        *,
        date(payment_month - interval '1 month') as previous_calendar_month,
        date(payment_month + interval '1 month') as next_calendar_month,

        lag(total_revenue)
            over(partition by user_id order by payment_month)
            as previous_paid_month_revenue,

        lag(payment_month)
            over(partition by user_id order by payment_month)
            as previous_paid_month,

        lead(payment_month)
            over(partition by user_id order by payment_month)
            as next_paid_month

    from table_1
),

revenue_metrics as (
    select
        payment_month,
        user_id,
        total_revenue,

        case
            when previous_paid_month is null
                then total_revenue
        end as new_mrr,

        case
            when previous_paid_month = previous_calendar_month
                and total_revenue > previous_paid_month_revenue
                then total_revenue - previous_paid_month_revenue
        end as expansion_revenue,

        case
            when previous_paid_month = previous_calendar_month
                and total_revenue < previous_paid_month_revenue
                then total_revenue - previous_paid_month_revenue
        end as contraction_revenue,

        case
            when previous_paid_month != previous_calendar_month
                and previous_paid_month is not null
                then total_revenue
        end as back_from_churn_revenue,

        case
            when next_paid_month is null
                or next_paid_month != next_calendar_month
                then total_revenue
        end as churned_revenue,

        case
            when next_paid_month is null
                or next_paid_month != next_calendar_month
                then next_calendar_month
        end as churn_month

    from table_2
)

select
    rm.*,
    gpu.game_name,
    gpu.language,
    gpu.has_older_device_model,
    gpu.age

from revenue_metrics rm

left join project.games_paid_users gpu
    using(user_id);
