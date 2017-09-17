#!/usr/bin/perl

use 5.10.0;
use DateTime;
use DateTime::Format::DateParse;

use Date::Format;
use warnings;
use strict;

my $start_date = DateTime::Format::DateParse->parse_datetime('2017-05-05');

# кредит 1 млн ру.
my $credit = 1_000_000;

# ставка 5%
my $percent = 0.05 / 12;

# инфляция 10%
my $infl = 0.1 / 12;

# кредит на 180 месяцев
my $length = 180;

sub add_months {
    my $m    = shift;
    my $date = shift;

    my $candidate = $start_date->clone->add( months => $m );
    if ( $candidate->month - $date->month > 1 ) {
        my $next_month = DateTime->last_day_of_month(
            year  => $date->year,
            month => $date->month
        )->add( days => 1 );
        return DateTime->last_day_of_month(
            year  => $next_month->year,
            month => $next_month->month
        );
    }
    else {
        return $candidate;
    }
}

my $credit_body = $credit;
my $credit_percent;

my $sum_pay      = 0;
my $real_sum_pay = 0;
my $infl_coef    = 1;

my $date   = $start_date->clone;
my $period = 0;
while ( $credit_body > 1 ) {
    $period++;
    my $pay =
      $credit * ( $percent + ( $percent / ( ( 1 + $percent )**$length - 1 ) ) );
    $pay = ( $pay > $credit_body ) ? $credit_body : $pay;
    $pay = sprintf( '%0.2f', $pay );

    my $prev_date = $date->clone;
    $date = add_months( $period, $date );

    my $first_day_of_new_month = $date->clone->truncate( to => 'month' );

    # say "$prev_date - $date - $first_day_of_new_month";

    my $days_period1;
    if ( ( $first_day_of_new_month - $prev_date )->in_units('days') == 0 ) {
        my $last_day = DateTime->last_day_of_month(
            year  => $prev_date->year,
            month => $prev_date->month
        );
        $days_period1 =
          ( $last_day - $last_day->clone->truncate( to => 'month' ) )
          ->in_units('days') + 1;
    }
    else {
        $days_period1 =
          ( $first_day_of_new_month - $prev_date )->in_units('days');
    }
    my $days_period2 = ( $date - $first_day_of_new_month )->in_units('days');

    # say("$first_day_of_new_month - $prev_date = $days_period1");
    # say("$date - $first_day_of_new_month = $days_period2");

    my $days_period1_days_in_year = ( $prev_date->is_leap_year ) ? 366 : 365;
    my $days_period2_days_in_year = ( $date->is_leap_year )      ? 366 : 365;

    if ( $pay == $credit_body ) {
        $credit_percent = 0;
    }
    else {
        $credit_percent =
          $credit_body *
          ( $percent * 12 ) *
          $days_period1 /
          $days_period1_days_in_year;
        $credit_percent +=
          $credit_body *
          ( $percent * 12 ) *
          $days_period2 /
          $days_period2_days_in_year;

        $credit_percent = sprintf '%.02f', $credit_percent;
    }

    my $credit_body_minus = sprintf '%.02f', $pay - $credit_percent;
    $credit_body = sprintf '%.02f', $credit_body - $credit_body_minus;

    say
"$date ($period) : $pay руб, выплата процентов $credit_percent руб., тела кредита $credit_body_minus руб. Остаток задолженности $credit_body";

    $infl_coef *= 1 + $infl;
    $sum_pay += $pay;
    $real_sum_pay += $pay / $infl_coef;

    my $decr_sum = sub {
        my $s = shift;
        $credit_body -= $s;
        $credit      -= $s;
        $sum_pay += $s;
        $real_sum_pay += $s / $infl_coef;
        say( "decr sum for $s, total payment = ", $s + $pay );
    };

    my $decr_months = sub {
        my $s = shift;
        $credit_body -= $s;
        $sum_pay += $s;
        $real_sum_pay += $s / $infl_coef;
        say( "decr months for $s, total payment = ", $s + $pay );
    };

    if ( $date->year == 2017 && $date->month == 5 ) {
        $decr_months->(10_000)
          ; # заплатить 2017-05 дополнительно 10 тысяч рублей в счёт погашения срока
    }

    if ( $date->year > 2017 || $date->month > 9 ) {

        $decr_sum->(100)
          ; # начиная с 2017-10 дополнительно платить по 100 рублей в счёт уменьшения ежемесячной суммы
    }
}

say "дата последнего платежа: $date";
printf "сумма платежей: %i т.р.\n", $sum_pay / 1000;
printf
  "реальный платеж с учетом инфляции: %i т.р.\n",
  $real_sum_pay / 1000;
