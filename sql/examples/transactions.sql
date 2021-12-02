EXECUTE BLOCK
AS
  DECLARE conn_str varchar(512) CHARACTER SET UTF8;
  DECLARE sql_txt VARCHAR(8191) CHARACTER SET UTF8;
  DECLARE sql_txt2 VARCHAR(8191) CHARACTER SET UTF8;
  DECLARE conn ty$pointer;
  DECLARE stmt ty$pointer;
  DECLARE stmt2 ty$pointer;
  DECLARE tnx ty$pointer;
BEGIN
  conn_str = 'DRIVER={PostgreSQL ODBC Driver(UNICODE)};SERVER=localhost;DATABASE=test;UID=postgres;PASSWORD=mypassword';
  sql_txt = 'insert into t1(id, name) values(?, ?)';
  sql_txt2 = 'insert into t2(id, name) values(?, ?)';

  -- инициализация nanodbc
  -- эту функцию можно вызывать в ON CONNECT триггере
  nano$udr.initialize(); 
  
  BEGIN
    -- соединение с источником данных ODBC
    conn = nano$conn.connection(conn_str);
    WHEN EXCEPTION nano$nanodbc_error DO
    BEGIN
      -- если соединение было неудачным
      -- вызываем функцию для завершения работы nanodbc
      -- вместо явного вызова в скрипте эту функцию можно вызывать 
      -- в ON DISCONNECT триггере      
      nano$udr.finalize();
      EXCEPTION;
    END
  END
  
  BEGIN
    -- подготавливаем первый SQL запрос
    stmt = nano$stmt.statement_(conn);
    nano$stmt.prepare_(stmt, sql_txt);
    -- подготавливаем второй SQL запрос
    stmt2 = nano$stmt.statement_(conn);
    nano$stmt.prepare_(stmt2, sql_txt2);
    -- стартуем транзакцию
    tnx = nano$tnx.transaction_(conn);
    --выполняем первый запрос в рамках транзакции
    nano$stmt.bind_integer(stmt, 0, 8);
    nano$stmt.bind_u8_varchar(stmt, 1, 'Строка 8', 4 * 20);
    nano$stmt.just_execute(stmt);
    --выполняем второй запрос в рамках транзакции
    nano$stmt.bind_integer(stmt2, 0, 1);
    nano$stmt.bind_u8_varchar(stmt2, 1, 'Строка 1', 4 * 20);
    nano$stmt.just_execute(stmt2);
    -- подтверждаем транзакцию
    nano$tnx.commit_(tnx);

    -- освобождаем ранее выделенные ресурсы
    conn = nano$conn.release_(conn);
    -- вызываем функцию для завершения работы nanodbc
    -- вместо явного вызова в скрипте эту функцию можно вызывать в 
    -- ON DISCONNECT триггере      
    nano$udr.finalize();

    WHEN EXCEPTION nano$invalid_resource,
         EXCEPTION nano$nanodbc_error,
         EXCEPTION nano$binding_error
    DO
    BEGIN
      -- освобождаем ранее выделенные ресурсы
      -- в случаем ошибки неподтверждённая транзакция откатится автоматически
      conn = nano$conn.release_(conn);
      -- вызываем функцию для завершения работы nanodbc
      -- вместо явного вызова в скрипте эту функцию можно вызывать в 
      -- ON DISCONNECT триггере         
      nano$udr.finalize();
      EXCEPTION;
    END
  END
END
