# UDR nanodbc

СУБД Firebird начиная с версии 2.5 имеет возможность работать с внешними данными через оператор `EXECUTE STATEMENT .. ON EXTERNAL DATA SOURCE`. 
К сожалению работа с внешними источниками данных ограничена только базами данных Firebird.

Для устранения этого недостатка была написана [UDR nanodbc](https://github.com/mnf71/udr-nanodbc).
Библиотека с полностью открытыми исходными кодами под лицензией MIT и свободна для использования. 
Она написана на языке C++. Её автор Максим Филатов является сотрудником Московской Биржи.

Библиотека основана на тонкой обёртке для С++ вокруг нативного C ODBC API [https://github.com/nanodbc/nanodbc](https://github.com/nanodbc/nanodbc).

## Установка UDR nanodbc

Установить UDR nanodbc можно начиная с Firebird 3.0 и выше (Firebird 2.5 не поддерживал UDR).
Вы можете собрать библиотеку скачав исходные код по ссылке выше, либо скачать готовую библиотеку под нужную вам платформу по адресу [https://github.com/mnf71/udr-nanodbc/tree/master/build](https://github.com/mnf71/udr-nanodbc/tree/master/build).

После скачивания или сборки готовую библиотеку необходимо разместить в каталог
- в Windows — `firebird\plugins\udr` (необходимо скопировать все `.dll` файлы)
- в Linux — `/firebird/plugins/udr` (необходимо распаковать и скопировать все `.so` файлы)

где firebird — корневой каталог установки Firebird.

Далее библиотеку необходимо зарегистрировать в вашей базе данных. Для этого необходимо выполнить последовательно следуюшие скрипты:

1. [sql/ty$.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/ty%24.sql)
2. [sql/except.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/except.sql)
3. [sql/udr.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/udr.sql)
4. [sql/conn.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/conn.sql)
5. [sql/tnx.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/tnx.sql)
6. [sql/stmt.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/stmt.sql)
7. [sql/rslt.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/rslt.sql)
8. [sql/func.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/func.sql)
9. [sql/ctlg.sql](https://github.com/mnf71/udr-nanodbc/blob/master/sql/ctlg.sql)

## Как это работает

UDR nanodbc основана на свободной библиотеке [nanodbc](https://github.com/nanodbc/nanodbc), поэтому для полного понимания рекомендуем изучить API этой иблиотеки в её исходных кодах и документации.

При работе с объектами библиотеки используются так называемые декрипторы (указатели на объекты nanodbc). Указатели описываются доменом определённым как:

```sql
CREATE DOMAIN TY$POINTER AS
CHAR(8) CHARACTER SET OCTETS;
```

в Firebird 4.0 он может быть описан следующим способом

```sql
CREATE DOMAIN TY$POINTER AS BINARY(8);
```

После завершения работы с объектом указатель на него необходимо освободить при помощи функций `release_()`, которые расположены в соответсвующих PSQL пакетах. Какой пакет использовать зависит от типа объекта, указатель на который необходимо освободить.

В Firebird невозможно создать функцию не возвращающую результат, поэтому для C++ функций с типом возврата void, UDR функции возвращают тип описанный доменом `TY$NANO_BLANK`. Не имеет смысл анализировать результат таких функций. Домен `TY$NANO_BLANK` описан как:

```sql
CREATE DOMAIN TY$NANO_BLANK AS SMALLINT;
```

Перед началом работы с UDR необходимо провести инициализацию библиотеки nanodbc. Это делается с помощью вызова функци `nano$udr.initialize()`. А по завершению работу вызвать функцию финализации `nano$udr.finalize()`. Функцию `nano$udr.initialize()` рекомендуется вызывать в ON CONNECT триггере, а функцию `nano$udr.finalize()` в ON DISCONNECT триггере.

## Описание PSQL пакетов из UDR nanodbc

### Пакет NANO$UDR

Заголовок этого пакета выглядит следующим образом:

```sql
CREATE OR ALTER PACKAGE NANO$UDR
AS
BEGIN

  FUNCTION initialize RETURNS TY$NANO_BLANK;
  FUNCTION finalize RETURNS TY$NANO_BLANK;
  FUNCTION expunge RETURNS TY$NANO_BLANK;

  FUNCTION locale(
      set_locale VARCHAR(20) CHARACTER SET NONE DEFAULT NULL /* NULL - Get */
    ) RETURNS CHARACTER SET NONE VARCHAR(20);

  FUNCTION error_message RETURNS VARCHAR(512) CHARACTER SET UTF8;

END
```

Пакет `NANO$UDR` содержит функции инициализации и финализации UDR.

Функция `initialize()` инициализирует UDR nanodbc. Эту функции рекомендуется вызывать в ON CONNECT триггере. Её необходимо вызывать перед первым обращением к любой другой функции из UDR nanodbc.

Функция `finalize()` завершает работу UDR nanodbc. После её вызова работа с UDR nanodbc невозможна. При вызове функция автоматически освобождает все ранее выделенные ресурсы. Эту функцию рекомендуется вызывать в ON DISCONNECT триггере.

Функция `expunge()` автоматически освобождает все ранее выделенные ресурсы (соединения, транзакции, подготовленные запросы, курсоры).

Функция `locale()` возвращает или устанавливает значение кодировки для соединений по умолчанию. Если параметр `set_locale` задан, то будет произведена установка новой кодировки, в противном случае функция вернёт значение текущей кодировки. 

Функция `error_message()` возвращает текст последней ошибки.

### Пакет NANO$CONN

Заголовок этого пакета выглядит следующим образом:

```sql
CREATE OR ALTER PACKAGE NANO$CONN
AS
BEGIN

  /*  Note:
        CHARACTER SET UTF8
        attr VARCHAR(512) CHARACTER SET UTF8 DEFAULT NULL
        ...
        CHARACTER SET WIN1251
        attr VARCHAR(2048) CHARACTER SET WIN1251 DEFAULT NULL
   */

  FUNCTION connection(
      attr VARCHAR(512) CHARACTER SET UTF8 DEFAULT NULL,
      user_ VARCHAR(63) CHARACTER SET UTF8 DEFAULT NULL,
      pass VARCHAR(63) CHARACTER SET UTF8 DEFAULT NULL,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$POINTER;

  FUNCTION valid(conn TY$POINTER NOT NULL) RETURNS BOOLEAN;

  FUNCTION release_(conn TY$POINTER NOT NULL) RETURNS TY$POINTER;
  FUNCTION expunge(conn ty$pointer NOT NULL) RETURNS TY$NANO_BLANK;

  FUNCTION allocate(conn ty$pointer NOT NULL) RETURNS TY$NANO_BLANK;
  FUNCTION deallocate(conn ty$pointer NOT NULL) RETURNS TY$NANO_BLANK;

  FUNCTION txn_read_uncommitted RETURNS SMALLINT;
  FUNCTION txn_read_committed RETURNS SMALLINT;
  FUNCTION txn_repeatable_read RETURNS SMALLINT;
  FUNCTION txn_serializable RETURNS SMALLINT;

  FUNCTION isolation_level(
      conn TY$POINTER NOT NULL,
      level_ SMALLINT DEFAULT NULL /* NULL - get usage */
    ) RETURNS SMALLINT;

  FUNCTION connect_(
      conn TY$POINTER NOT NULL,
      attr VARCHAR(512) CHARACTER SET UTF8 NOT NULL,
      user_ VARCHAR(63) CHARACTER SET UTF8 DEFAULT NULL,
      pass VARCHAR(63) CHARACTER SET UTF8 DEFAULT NULL,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION connected(conn TY$POINTER NOT NULL) RETURNS BOOLEAN;

  FUNCTION disconnect_(conn ty$pointer NOT NULL) RETURNS TY$NANO_BLANK;

  FUNCTION transactions(conn TY$POINTER NOT NULL) RETURNS INTEGER;

  FUNCTION get_info(conn TY$POINTER NOT NULL, info_type SMALLINT NOT NULL)
    RETURNS VARCHAR(256) CHARACTER SET UTF8;

  FUNCTION dbms_name(conn ty$pointer NOT NULL) RETURNS VARCHAR(128) CHARACTER SET UTF8;
  FUNCTION dbms_version(conn ty$pointer NOT NULL) RETURNS VARCHAR(128) CHARACTER SET UTF8;
  FUNCTION driver_name(conn TY$POINTER NOT NULL) RETURNS VARCHAR(128) CHARACTER SET UTF8;
  FUNCTION database_name(conn TY$POINTER NOT NULL) RETURNS VARCHAR(128) CHARACTER SET UTF8;
  FUNCTION catalog_name(conn TY$POINTER NOT NULL) RETURNS VARCHAR(128) CHARACTER SET UTF8;

END
```

Пакет `NANO$CONN` содержит функции для установки и источником данных ODBC, а также получении некоторой информации о соединении.

Функция `connection()` устанавливает соединение с источником данных ODBC. Если не один параметр не задан, то функция вернёт указатель на объект "соединение". Непосредственно само соединение с источником данных ODBC можно выполнить позднее с помощью функции `connect_()`.  Параметры функции:
-  `attr` задаёт строку подключения или так называемый DSN; 
-  `user_` задаёт имя пользователя;
-  `pass` задаёт пароль;
-  `timeout` задаёт тайм-аут простоя.

Функция `valid()` возвращает является ли указатель на объект соединения корректным.  

Функция `release_()` освобождает указатель на соединение и все связанные с ним ресурсы (транзакции, подготовленные запросы, курсоры).

Функция `expunge()` освобождает все связанные с соединением ресурсы (транзакции, подготовленные запросы, курсоры).

Функция `allocate()` позволяет по требованию выделять дескрипторы для настройки среды и атрибутов ODBC до установления соединения с базой данных. Обычно пользователю не нужно делать этот вызов явно. 

Функция `deallocate()` освобождает дескрипторы подключения.

Функция `txn_read_uncommitted()` возвращает числовую константу, которая требуется для установки уровня изолированности транзакции READ UNCOMMITTED.

Функция `txn_read_committed()` возвращает числовую константу, которая требуется для установки уровня изолированности транзакции READ COMMITTED.

Функция `txn_repeatable_read()` возвращает числовую константу, которая требуется для установки уровня изолированности транзакции REPEATABLE READ.

Функция `txn_serializable()` возвращает числовую константу, которая требуется для установки уровня изолированности транзакции SERIALIZABLE.

Функция `isolation_level()` устанавливает уровень изолированности для новых транзакций. Параметры:
- `conn` - указатель на объект соединения;
- `level_` - уровень изолированности транзакции, должно быть одним из чисел возвращаемых функциями `tnx_*`.
  
Функция `connect_()` устанавливает соединение с источником данных ODBC и привязывает его к переданному указателю на объект соединения.
Параметры функции:
-  `conn` указатель на объект соединения;
-  `attr` задаёт строку подключения или так называемый DSN; 
-  `user_` задаёт имя пользователя;
-  `pass` задаёт пароль;
-  `timeout` задаёт тайм-аут простоя.

Функция `connected()` возвращает установлено ли соединение с базой данных для заданного указателя на объект соединения.

Функция `disconnect_()` отключается от базы данных. В качестве параметра передаётся указатель на объект соединения.

Функция `transactions()` возвращает количество активных транзакций для заданного соединения.

Функция `get_info()` ...


### Пакет NANO$TNX

Заголовок этого пакета выглядит следующим образом:

```sql
CREATE OR ALTER PACKAGE NANO$TNX
AS
BEGIN
 
  FUNCTION transaction_(conn TY$POINTER NOT NULL) RETURNS TY$POINTER;

  FUNCTION valid(tnx TY$POINTER NOT NULL) RETURNS BOOLEAN;

  FUNCTION release_(tnx ty$pointer NOT NULL) RETURNS TY$POINTER;

  FUNCTION connection(tnx TY$POINTER NOT NULL) RETURNS TY$POINTER;

  FUNCTION commit_(tnx TY$POINTER NOT NULL) RETURNS TY$NANO_BLANK;
  FUNCTION rollback_(tnx TY$POINTER NOT NULL) RETURNS TY$NANO_BLANK;

END
```

### Пакет NANO$STMT

Заголовок этого пакета выглядит следующим образом:

```sql
CREATE OR ALTER PACKAGE NANO$STMT
AS
BEGIN

  FUNCTION statement_(
      conn TY$POINTER DEFAULT NULL,
      query VARCHAR(8191) CHARACTER SET UTF8 DEFAULT NULL,
      scrollable BOOLEAN DEFAULT NULL /* NULL - default ODBC driver */,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$POINTER;

  FUNCTION valid(stmt TY$POINTER NOT NULL) RETURNS BOOLEAN;

  FUNCTION release_(stmt TY$POINTER NOT NULL) RETURNS TY$POINTER;

  FUNCTION connected(stmt TY$POINTER NOT NULL) RETURNS BOOLEAN;
  FUNCTION connection(stmt TY$POINTER NOT NULL) RETURNS TY$POINTER;

  FUNCTION open_(
      stmt TY$POINTER NOT NULL,
      conn TY$POINTER NOT NULL
    ) RETURNS TY$NANO_BLANK;

  FUNCTION close_(stmt TY$POINTER NOT NULL) RETURNS TY$NANO_BLANK;

  FUNCTION cancel(stmt TY$POINTER NOT NULL) RETURNS TY$NANO_BLANK;

  FUNCTION closed(stmt TY$POINTER NOT NULL) RETURNS BOOLEAN;

  FUNCTION prepare_direct(
      stmt TY$POINTER NOT NULL,
      conn TY$POINTER NOT NULL,
      query VARCHAR(8191) CHARACTER SET UTF8 NOT NULL,
      scrollable BOOLEAN DEFAULT NULL /* NULL - default ODBC driver */,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION prepare_(
      stmt TY$POINTER NOT NULL,
      query VARCHAR(8191) CHARACTER SET UTF8 NOT NULL,
      scrollable BOOLEAN DEFAULT NULL /* NULL - default ODBC driver */,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION scrollable(
      stmt TY$POINTER NOT NULL,
      usage_ BOOLEAN DEFAULT NULL /* NULL - get usage */
    ) RETURNS BOOLEAN;

  FUNCTION timeout(
      stmt TY$POINTER NOT NULL,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION execute_direct(
      stmt TY$POINTER NOT NULL,
      conn TY$POINTER NOT NULL,
      query VARCHAR(8191) CHARACTER SET UTF8 NOT NULL,
      scrollable BOOLEAN DEFAULT NULL /* NULL - default ODBC driver */,
      batch_operations INTEGER NOT NULL DEFAULT 1,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$POINTER;

  FUNCTION just_execute_direct(
      stmt TY$POINTER NOT NULL,
      conn TY$POINTER NOT NULL,
      query VARCHAR(8191) CHARACTER SET UTF8 NOT NULL,
      batch_operations INTEGER NOT NULL DEFAULT 1,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION execute_(
      stmt TY$POINTER NOT NULL,
      batch_operations INTEGER NOT NULL DEFAULT 1,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$POINTER;

  FUNCTION just_execute(
      stmt TY$POINTER NOT NULL,
      batch_operations INTEGER NOT NULL DEFAULT 1,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION procedure_columns(
      stmt TY$POINTER NOT NULL,
      catalog_ VARCHAR(128) CHARACTER SET UTF8 NOT NULL,
      schema_ VARCHAR(128) CHARACTER SET UTF8 NOT NULL,
      procedure_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL,
      column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS TY$POINTER;

  FUNCTION affected_rows(stmt TY$POINTER NOT NULL) RETURNS INTEGER;
  FUNCTION columns(stmt TY$POINTER NOT NULL) RETURNS SMALLINT;
  FUNCTION parameters(stmt TY$POINTER NOT NULL) RETURNS SMALLINT;
  FUNCTION parameter_size(stmt TY$POINTER NOT NULL, parameter_index SMALLINT NOT NULL)
    RETURNS INTEGER;

  ------------------------------------------------------------------------------

  FUNCTION bind_smallint(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ SMALLINT
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_integer(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ INTEGER
    ) RETURNS TY$NANO_BLANK;

/*
  FUNCTION bind_bigint(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ BIGINT
    ) RETURNS TY$NANO_BLANK;
*/

  FUNCTION bind_float(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ FLOAT
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_double(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ DOUBLE PRECISION
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_varchar(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ VARCHAR(32765) CHARACTER SET NONE,
      param_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_char(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ CHAR(32767) CHARACTER SET NONE,
      param_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_u8_varchar(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ VARCHAR(8191) CHARACTER SET UTF8,
      param_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_u8_char(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ CHAR(8191) CHARACTER SET UTF8,
      param_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_blob(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ BLOB
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_boolean(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ BOOLEAN
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_date(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ DATE
    ) RETURNS TY$NANO_BLANK;

/*
  FUNCTION bind_time(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ TIME
    ) RETURNS TY$NANO_BLANK
    EXTERNAL NAME 'nano!stmt_bind'
    ENGINE UDR;
*/

  FUNCTION bind_timestamp(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      value_ TIMESTAMP
    ) RETURNS TY$NANO_BLANK;

  FUNCTION bind_null(
      stmt TY$POINTER NOT NULL,
      parameter_index SMALLINT NOT NULL,
      batch_size INTEGER NOT NULL DEFAULT 1 -- <> 1 call nulls all batch
    ) RETURNS TY$NANO_BLANK;

  FUNCTION convert_varchar(
      value_ VARCHAR(32765) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS VARCHAR(32765) CHARACTER SET NONE;

  FUNCTION convert_char(
      value_ CHAR(32767) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS CHAR(32767) CHARACTER SET NONE;

  FUNCTION clear_bindings(stmt TY$POINTER NOT NULL) RETURNS TY$NANO_BLANK;

  ------------------------------------------------------------------------------

  FUNCTION describe_parameter(
      stmt TY$POINTER NOT NULL,
      idx SMALLINT NOT NULL,
      type_ SMALLINT NOT NULL,
      size_ INTEGER NOT NULL,
      scale_ SMALLINT NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION describe_parameters(stmt TY$POINTER NOT NULL) RETURNS TY$NANO_BLANK;

  FUNCTION reset_parameters(stmt TY$POINTER NOT NULL, timeout INTEGER NOT NULL DEFAULT 0)
    RETURNS TY$NANO_BLANK;

END
```

### Пакет NANO$RSLT

Заголовок этого пакета выглядит следующим образом:

```sql
CREATE OR ALTER PACKAGE NANO$RSLT
AS
BEGIN

  FUNCTION valid(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;

  FUNCTION release_(rslt TY$POINTER NOT NULL) RETURNS TY$POINTER;

  FUNCTION connection(rslt TY$POINTER NOT NULL) RETURNS TY$POINTER;

  FUNCTION rowset_size(rslt TY$POINTER NOT NULL) RETURNS INTEGER;
  FUNCTION affected_rows(rslt TY$POINTER NOT NULL) RETURNS INTEGER;
  FUNCTION has_affected_rows(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;
  FUNCTION rows_(rslt TY$POINTER NOT NULL) RETURNS INTEGER;
  FUNCTION columns(rslt TY$POINTER NOT NULL) RETURNS SMALLINT;

  ------------------------------------------------------------------------------

  FUNCTION first_(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;
  FUNCTION last_(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;
  FUNCTION next_(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;
  FUNCTION prior_(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;
  FUNCTION move(rslt TY$POINTER NOT NULL, row_ INTEGER NOT NULL) RETURNS BOOLEAN;
  FUNCTION skip_(rslt TY$POINTER NOT NULL, row_ INTEGER NOT NULL) RETURNS BOOLEAN;
  FUNCTION position_(rslt TY$POINTER NOT NULL) RETURNS INTEGER;
  FUNCTION at_end(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;

  ------------------------------------------------------------------------------

  FUNCTION get_smallint(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS SMALLINT;

  FUNCTION get_integer(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS INTEGER;

/*
  FUNCTION get_bigint(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS BIGINT;
*/

  FUNCTION get_float(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS FLOAT;

  FUNCTION get_double(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS DOUBLE PRECISION;

  FUNCTION get_varchar_s(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(64) CHARACTER SET NONE;

  FUNCTION get_varchar(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(256) CHARACTER SET NONE;

  FUNCTION get_varchar_l(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(1024) CHARACTER SET NONE;

  FUNCTION get_varchar_xl (
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(8192) CHARACTER SET NONE;

  FUNCTION get_varchar_xxl (
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(32765) CHARACTER SET NONE;

  FUNCTION get_char_s (
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(64) CHARACTER SET NONE;

  FUNCTION get_char (
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(256) CHARACTER SET NONE;

  FUNCTION get_char_l (
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(1024) CHARACTER SET NONE;

  FUNCTION get_char_xl(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(8192) CHARACTER SET NONE;

  FUNCTION get_char_xxl(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(32767) CHARACTER SET NONE;

  FUNCTION get_u8_varchar(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(64) CHARACTER SET UTF8;

  FUNCTION get_u8_varchar_l(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(256) CHARACTER SET UTF8;

  FUNCTION get_u8_varchar_xl(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(2048) CHARACTER SET UTF8;

  FUNCTION get_u8_varchar_xxl(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS VARCHAR(8191) CHARACTER SET UTF8;

  FUNCTION get_u8_char(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(64) CHARACTER SET UTF8;

  FUNCTION get_u8_char_l(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(256) CHARACTER SET UTF8;

  FUNCTION get_u8_char_xl(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(2048) CHARACTER SET UTF8;

  FUNCTION get_u8_char_xxl(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS CHAR(8191) CHARACTER SET UTF8;

  FUNCTION get_blob(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS BLOB;

  FUNCTION get_boolean(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS BOOLEAN;

  FUNCTION get_date(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS DATE;

/*
  FUNCTION get_time(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS TIME;
*/

  FUNCTION get_timestamp(
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL
    ) RETURNS TIMESTAMP;

  FUNCTION convert_varchar_s(
      value_ VARCHAR(64) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS VARCHAR(64) CHARACTER SET NONE;

  FUNCTION convert_varchar(
      value_ VARCHAR(256) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS VARCHAR(256) CHARACTER SET NONE;

  FUNCTION convert_varchar_l(
      value_ VARCHAR(1024) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS VARCHAR(1024) CHARACTER SET NONE;

  FUNCTION convert_varchar_xl(
      value_ VARCHAR(8192) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS VARCHAR(8192) CHARACTER SET NONE;

  FUNCTION convert_varchar_xxl(
      value_ VARCHAR(32765) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS VARCHAR(32765) CHARACTER SET NONE;

  FUNCTION convert_char_s(
      value_ CHAR(64) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS CHAR(64) CHARACTER SET NONE;

  FUNCTION convert_char(
      value_ CHAR(256) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS CHAR(256) CHARACTER SET NONE;

  FUNCTION convert_char_l(
      value_ CHAR(1024) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS CHAR(1024) CHARACTER SET NONE;

  FUNCTION convert_char_xl(
      value_ CHAR(8192) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS CHAR(8192) CHARACTER SET NONE;

  FUNCTION convert_char_xxl(
      value_ CHAR(32767) CHARACTER SET NONE,
      from_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      to_ VARCHAR(20) CHARACTER SET NONE NOT NULL,
      convert_size SMALLINT NOT NULL DEFAULT 0
    ) RETURNS CHAR(32767) CHARACTER SET NONE;

  ------------------------------------------------------------------------------

  FUNCTION unbind(rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS TY$NANO_BLANK;

  FUNCTION is_null(rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS BOOLEAN;

  FUNCTION is_bound( -- now hiding exception out of range
      rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS BOOLEAN;

  FUNCTION column_(rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS SMALLINT;

  FUNCTION column_name(rslt TY$POINTER NOT NULL, index_ SMALLINT NOT NULL)
    RETURNS VARCHAR(63) CHARACTER SET UTF8;

  FUNCTION column_size(rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS INTEGER;

  FUNCTION column_decimal_digits(rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS INTEGER;

  FUNCTION column_datatype(rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS INTEGER;

  FUNCTION column_datatype_name(rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS VARCHAR(63) CHARACTER SET UTF8;

  FUNCTION column_c_datatype(rslt TY$POINTER NOT NULL, column_ VARCHAR(63) CHARACTER SET UTF8 NOT NULL)
    RETURNS INTEGER;

  FUNCTION next_result(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;

  ------------------------------------------------------------------------------

  FUNCTION has_data(rslt TY$POINTER NOT NULL) RETURNS BOOLEAN;

END
```

### Пакет NANO$FUNC

Заголовок этого пакета выглядит следующим образом:

```sql
CREATE OR ALTER PACKAGE NANO$FUNC
AS
BEGIN
  
  /*  Note:
        Result cursor by default ODBC driver (NANODBC implementation),
        scrollable into NANO$STMT
   */

  FUNCTION execute_conn(
      conn TY$POINTER NOT NULL,
      query VARCHAR(8191) CHARACTER SET UTF8 NOT NULL,
      batch_operations INTEGER NOT NULL DEFAULT 1,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$POINTER;

  FUNCTION just_execute_conn(
      conn TY$POINTER NOT NULL,
      query VARCHAR(8191) CHARACTER SET UTF8 NOT NULL,
      batch_operations INTEGER NOT NULL DEFAULT 1,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

  FUNCTION execute_stmt(
      stmt TY$POINTER NOT NULL, batch_operations INTEGER NOT NULL DEFAULT 1
    ) RETURNS TY$POINTER;

  FUNCTION just_execute_stmt(
      stmt TY$POINTER NOT NULL, batch_operations INTEGER NOT NULL DEFAULT 1
    ) RETURNS TY$NANO_BLANK;

  FUNCTION transact_stmt(
      stmt TY$POINTER NOT NULL, batch_operations INTEGER NOT NULL DEFAULT 1
    ) RETURNS TY$POINTER;

  FUNCTION just_transact_stmt(
      stmt TY$POINTER NOT NULL, batch_operations INTEGER NOT NULL DEFAULT 1
    ) RETURNS TY$NANO_BLANK;

  FUNCTION prepare_stmt(
      stmt TY$POINTER NOT NULL,
      query VARCHAR(8191) CHARACTER SET UTF8 NOT NULL,
      timeout INTEGER NOT NULL DEFAULT 0
    ) RETURNS TY$NANO_BLANK;

END
```

