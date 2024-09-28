-- seed

CREATE FUNCTION generate_unique_id() RETURNS VARCHAR LANGUAGE javascript AS $$
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = (Math.random() * 16) | 0,
        v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
$$;

CREATE TABLE streampay_commands(
    type VARCHAR,
    user_id VARCHAR,
    requestid VARCHAR,
    amount DOUBLE PRECISION,
    notes VARCHAR
)
INCLUDE zilla_correlation_id AS correlation_id
INCLUDE zilla_identity AS owner_id
INCLUDE timestamp as timestamp;

CREATE TABLE streampay_users(
  id VARCHAR,
  name VARCHAR,
  username VARCHAR,
  PRIMARY KEY (id)
);

CREATE VIEW user_transactions AS
  SELECT
      encode(owner_id, 'escape') AS user_id,
      -amount AS net_amount
  FROM streampay_commands
  WHERE type = 'SendPayment'
  UNION ALL
  SELECT
      user_id as user_id,
      amount AS net_amount
  FROM streampay_commands
  WHERE type = 'SendPayment';

CREATE MATERIALIZED VIEW streampay_balances AS
  SELECT
      user_id,
      SUM(net_amount) AS balance
  FROM user_transactions
  GROUP BY user_id;

CREATE MATERIALIZED VIEW streampay_payment_requests as
  SELECT
      generate_unique_id() as id,
      encode(cmd.owner_id, 'escape') as from_user_id,
      u2.username as from_username,
      cmd.user_id as to_user_id,
      u1.username as to_username,
      amount,
      notes
  FROM
      streampay_commands as cmd
  LEFT JOIN
      streampay_users u1 ON u1.id = cmd.user_id
  LEFT JOIN
      streampay_users u2 ON u2.id = encode(cmd.owner_id, 'escape')
  WHERE
      type = 'RequestPayment';

CREATE MATERIALIZED VIEW streampay_activities AS
  SELECT
      'PaymentSent' AS eventName,
      encode(sc.owner_id, 'escape') AS from_user_id,
      fu.username AS from_username,
      sc.user_id to_user_id,
      tu.username AS to_username,
      -sc.amount as amount,
      CAST(extract(epoch FROM sc.timestamp) AS FLOAT) * 1000 AS timestamp
  FROM
      streampay_commands sc
      LEFT JOIN streampay_users fu ON encode(sc.owner_id, 'escape') = fu.id
      LEFT JOIN streampay_users tu ON sc.user_id = tu.id
  WHERE
      sc.type = 'SendPayment'
  UNION ALL
  SELECT
      'PaymentReceived' AS eventName,
      encode(sc.owner_id, 'escape') AS from_user_id,
      tu.username AS from_username,
      sc.user_id AS to_user_id,
      fu.username AS to_username,
      sc.amount as amount,
      CAST(extract(epoch FROM sc.timestamp) AS FLOAT) * 1000 AS timestamp
  FROM
      streampay_commands AS sc
      LEFT JOIN streampay_users fu ON encode(sc.owner_id, 'escape') = fu.id
      LEFT JOIN streampay_users tu ON sc.user_id = tu.id
  WHERE
      sc.type = 'SendPayment'
  UNION ALL
  SELECT
      'PaymentRequested' AS eventName,
      encode(sc.owner_id, 'escape') AS from_user_id,
      fu.username AS from_username,
      sc.user_id AS to_user_id,
      tu.username AS to_username,
      sc.amount,
      CAST(extract(epoch FROM sc.timestamp) AS FLOAT) * 1000 AS timestamp
  FROM
      streampay_commands sc
      LEFT JOIN streampay_users fu ON encode(sc.owner_id, 'escape') = fu.id
      LEFT JOIN streampay_users tu ON sc.user_id = tu.id
  WHERE
      sc.type = 'RequestPayment';

CREATE TABLE streampay_balance_histories(
    balance DOUBLE PRECISION
)
INCLUDE timestamp AS timestamp;

CREATE VIEW IF NOT EXISTS invalid_status_code AS
    SELECT '400' as status, encode(correlation_id, 'escape') as correlation_id from streampay_commands where type NOT IN ('SendPayment', 'RequestPayment');

CREATE VIEW IF NOT EXISTS valid_status_code AS
    SELECT '200' as status,  encode(correlation_id, 'escape') as correlation_id from streampay_commands where type IN ('SendPayment', 'RequestPayment');

CREATE MATERIALIZED VIEW IF NOT EXISTS streampay_replies AS
    SELECT * FROM invalid_status_code
    UNION
    SELECT * FROM valid_status_code;
