EXECUTE BLOCK
AS
  DECLARE conn_str varchar(512) CHARACTER SET UTF8;
  declare variable sql_txt VARCHAR(8191) CHARACTER SET UTF8;
  DECLARE conn ty$pointer;
  DECLARE stmt ty$pointer;
  DECLARE tnx ty$pointer;
BEGIN
  conn_str = 'DRIVER={PostgreSQL ODBC Driver(UNICODE)};SERVER=localhost;DATABASE=test;UID=postgres;PASSWORD=mypassword';
  sql_txt = 'insert into t1(id, name) values(?, ?)';

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
    -- выделяем указатель на SQL оператор
    stmt = nano$stmt.statement_(conn);
    -- подготавливаем запрос
    nano$stmt.prepare_(stmt, sql_txt);
    -- устанавливаем параметры запроса
    -- индекс начинается с 0!
    -- первая запись
    nano$stmt.bind_integer(stmt, 0, 5);
    nano$stmt.bind_u8_varchar(stmt, 1, 'Строка 5', 4 * 20);
    -- вторая запись
    nano$stmt.bind_integer(stmt, 0, 6);
    nano$stmt.bind_u8_varchar(stmt, 1, 'Строка 6', 4 * 20);    
    -- выполняем оператор INSERT, с размером пакета 2
    nano$stmt.just_execute(stmt, 2);
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
      conn = nano$conn.release_(conn);
      -- вызываем функцию для завершения работы nanodbc
      -- вместо явного вызова в скрипте эту функцию можно вызывать в 
      -- ON DISCONNECT триггере  
      nano$udr.finalize();
      EXCEPTION;
    END
  END
END