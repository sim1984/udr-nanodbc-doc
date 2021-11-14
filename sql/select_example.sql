EXECUTE BLOCK
RETURNS (
  id bigint,
  name VARCHAR(1024) CHARACTER SET UTF8
)
AS
  DECLARE conn_str varchar(512) CHARACTER SET UTF8;
  declare variable sql_txt VARCHAR(8191) CHARACTER SET UTF8;
  DECLARE conn ty$pointer;
  DECLARE stmt ty$pointer;
  DECLARE rs ty$pointer;
  DECLARE tnx ty$pointer;
BEGIN
  conn_str = 'DRIVER={PostgreSQL ODBC Driver(UNICODE)};SERVER=localhost;DATABASE=test;UID=postgres;PASSWORD=Excimer2010';
  sql_txt = 'select * from t1';

  nano$udr.initialize(); -- maybe trigger on connect
  
  BEGIN
    conn = nano$conn.connection(conn_str);
    WHEN EXCEPTION nano$nanodbc_error DO
    BEGIN
      nano$udr.finalize();
      EXCEPTION;
    END
  END
  
  BEGIN
    stmt = nano$stmt.statement_(conn);
    nano$stmt.prepare_(stmt, sql_txt);
    rs = nano$stmt.execute_(stmt);

    while (nano$rslt.next_(rs)) do
    begin
      id = nano$rslt.get_integer(rs, 'id');
      name = nano$rslt.get_u8_char_l(rs, 'name');
      suspend;
    end

    rs = nano$rslt.release_(rs);
    stmt = nano$stmt.release_(stmt);
    conn = nano$conn.release_(conn);
    nano$udr.finalize(); -- better use in trigger on disconnect

    WHEN EXCEPTION nano$invalid_resource,
         EXCEPTION nano$nanodbc_error,
         EXCEPTION nano$binding_error
    DO
    BEGIN
      rs = nano$rslt.release_(rs);
      stmt = nano$stmt.release_(stmt);
      conn = nano$conn.release_(conn);
      nano$udr.finalize(); -- better use in trigger on disconnect
      EXCEPTION;
    END
  END
END
