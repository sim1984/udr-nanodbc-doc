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
  conn_str = 'DRIVER={PostgreSQL ODBC Driver(UNICODE)};SERVER=localhost;DATABASE=test;UID=postgres;PASSWORD=mypassword';
  sql_txt = 'select * from t1';

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
      -- после чего можно пробросить исключение далее 
      EXCEPTION;
    END
  END
  
  BEGIN
    -- выделяем указатель на SQL оператор
    stmt = nano$stmt.statement_(conn);
    -- подготавливаем запрос
    nano$stmt.prepare_(stmt, sql_txt);
    -- выполняем запрос
    -- функция возвращает указатель на набор данных
    rs = nano$stmt.execute_(stmt);
    -- пока в курсоре есть записи перемещаемся по нему вперёд
    while (nano$rslt.next_(rs)) do
    begin
      -- для каждого столбца необходимо в зависимости от его типа вызывать
      -- соответствующую функцию или функцию с типом в который возможно 
      -- преобразование исходного столбца
      id = nano$rslt.get_integer(rs, 'id');
      -- обратите внимание, поскольку мы работает с UTF8 вызывается функция с u8
      name = nano$rslt.get_u8_char_l(rs, 'name');
      suspend;
    end

    -- освобождаем ранее выделенные ресурсы
    /*
    rs = nano$rslt.release_(rs);
    stmt = nano$stmt.release_(stmt);
    */
    -- вышеперечисленные функции можно опустить, поскольку
    -- вызов nano$conn.release_ автоматически освободит все 
    -- привязанные к соединению ресурсы
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
      -- если произошла ошибка
      -- освобождаем ранее выделенные ресурсы
      /*
      rs = nano$rslt.release_(rs);
      stmt = nano$stmt.release_(stmt);
      */
    -- вышеперечисленные функции можно опустить, поскольку
    -- вызов nano$conn.release_ автоматически освободит все 
    -- привязанные к соединению ресурсы      
      conn = nano$conn.release_(conn);
      -- вызываем функцию для завершения работы nanodbc
      -- вместо явного вызова в скрипте эту функцию можно вызывать в ON DISCONNECT триггере      
      nano$udr.finalize(); 
      -- после чего можно пробросить исключение далее 
      EXCEPTION;
    END
  END
END