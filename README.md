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

Далее библиотеку необходимо зарегистрировать в вашей базе данных. Для этого необходимо выполнить последовательно следующие скрипты:

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

UDR nanodbc основана на свободной библиотеке [nanodbc](https://github.com/nanodbc/nanodbc), поэтому для полного понимания рекомендуем изучить API этой библиотеки в её исходных кодах и документации.

При работе с объектами библиотеки используются так называемые дескрипторы (указатели на объекты nanodbc). Указатели описываются доменом определённым как:

```sql
CREATE DOMAIN TY$POINTER AS
CHAR(8) CHARACTER SET OCTETS;
```

в Firebird 4.0 он может быть описан следующим способом

```sql
CREATE DOMAIN TY$POINTER AS BINARY(8);
```

После завершения работы с объектом указатель на него необходимо освободить при помощи функций `release_()`, которые расположены в соответствующих PSQL пакетах. Какой пакет использовать зависит от типа объекта, указатель на который необходимо освободить.

В Firebird невозможно создать функцию не возвращающую результат, поэтому для C++ функций с типом возврата void, UDR функции возвращают тип описанный доменом `TY$NANO_BLANK`. Не имеет смысл анализировать результат таких функций. Домен `TY$NANO_BLANK` описан как:

```sql
CREATE DOMAIN TY$NANO_BLANK AS SMALLINT;
```

Перед началом работы с UDR необходимо провести инициализацию библиотеки nanodbc. Это делается с помощью вызова функции `nano$udr.initialize()`. А по завершению работу вызвать функцию финализации `nano$udr.finalize()`. Функцию `nano$udr.initialize()` рекомендуется вызывать в ON CONNECT триггере, а функцию `nano$udr.finalize()` в ON DISCONNECT триггере.

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

Функция `locale()` возвращает или устанавливает значение кодировки для соединений по умолчанию. Если параметр `set_locale` задан, то будет произведена установка новой кодировки, в противном случае функция вернёт значение текущей кодировки. Это необходимо для преобразования передаваемых и получаемых строк, перед и после обмена с источником ODBC. По умолчанию установлена кодировка cp1251.

Если изначально соединение с БД установлено с кодировкой UTF8, то можно установить utf8, согласно названиям iconv. Если с кодировкой NONE, то лучше переводить в свою языковую кодировку с помощью функций `convert_[var]char()`.

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
-  `conn` - указатель на объект соединения;
-  `attr` задаёт строку подключения или так называемый DSN; 
-  `user_` задаёт имя пользователя;
-  `pass` задаёт пароль;
-  `timeout` задаёт тайм-аут простоя.

Функция `connected()` возвращает установлено ли соединение с базой данных для заданного указателя на объект соединения.

Функция `disconnect_()` отключается от базы данных. В качестве параметра передаётся указатель на объект соединения.

Функция `transactions()` возвращает количество активных транзакций для заданного соединения.

Функция `get_info()` возвращает различную информацию о драйвере или источнике данных. Это низкоуровневая функция является аналогом ODBC функции SQLGetInfo. Не рекомендуется использовать её напрямую. Параметры:
- `conn` - указатель на объект соединения;
- `info_type` - тип возвращаемой информации. Числовые константы с типами возвращаемой информации можно найти в https://github.com/microsoft/ODBC-Specification/blob/master/Windows/inc/sql.h
  

Функция `dbms_name()` возвращает имя СУБД к которой произведено подключение.

Функция `dbms_version()` возвращает версию СУБД к которой произведено подключение.

Функция `driver_name()` возвращает имя драйвера.

Функция `database_name()` возвращает имя базы данных к которой произведено подключение.

Функция `catalog_name()` возвращает имя каталога базы данных к которой произведено подключение.


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

Пакет `NANO$TNX` содержит функции для явного управления транзакциями.

Функция `transaction_()` отключает отключает автоматическое подтверждение транзакции и стартует новую транзакцию с уровнем изолированности указанным в функции `NANO$CONN.isolation_level()`. Функция возвращает указатель на новую транзакцию.

Функция `valid()` возвращает является ли указатель на объект транзакции корректным.

Функция `release_()` освобождает указатель на объект транзакции. При освобождении указателя не подтверждённая транзакция откатывается и драйвер возвращает в режим автоматического подтверждения транзакций.

Функция `connection()` возвращает указатель на соединение для которого была запущена транзакция.

Функция `commit_()` производит подтверждение транзакции.

Функция `rollback_()` производит откат транзакции.

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

Пакет `NANO$STMT` содержит функции для работы с SQL запросами.

Функция `statement_()` создаёт и возвращает указатель на объект SQL запрос. Параметры:
- `conn` - указатель на объект соединения;
- `query` - текст SQL запроса;
- `scrollable` - является ли курсор прокручиваемым (если конечно оператор возвращает курсор), если не задан (значение NULL), то используется поведения ODBC драйвера по умолчанию;
- `timeout` - тайм-аут SQL оператора.

Если не указан ни один параметр, то возвращает указатель на вновь созданный объект SQL запроса, без привязки к соединению. Позже этот указатель можно связать с соединением и задать другие свойства запроса. 

Функция `valid()` возвращает является ли указатель на объект SQL запроса корректным.

Функция `release_()` освобождает указатель на объект SQL запроса.

Функция `connected()` возвращает привязан ли запрос к подключению.

Функция `connection()`указатель на привязанное подключение.

Функция `open_()` открывает соединение и привязывает его к запросу. Параметры:
- `stmt` - указатель на SQL запрос;
- `conn` - указатель на подключение.
  
Функция `close_()` закрывает открытый ранее запрос и очищает все выделенные запросом ресурсы.

Функция `cancel()` отменяет выполнение запроса.

Функция `closed()` возвращает является ли запрос закрытым.

Функция `prepare_direct()` подготавливает SQL запрос и привязывает его к указанному соединению. Параметры:
- `stmt` - указатель на запрос;
- `conn` - указатель на соединение;
- `query` - текст SQL запроса;
- `scrollable` - является ли курсор прокручиваемым (если конечно оператор возвращает курсор), если не задан (значение NULL), то используется поведения ODBC драйвера по умолчанию;
- `timeout` - тайм-аут SQL оператора.

Функция `prepare_()` подготавливает SQL запрос. Параметры:
- `stmt` - указатель на запрос;
- `query` - текст SQL запроса;
- `scrollable` - является ли курсор прокручиваемым (если конечно оператор возвращает курсор), если не задан (значение NULL), то используется поведения ODBC драйвера по умолчанию;
- `timeout` - тайм-аут SQL оператора.

Функция `scrollable_()` возвращает или устанавливает будет ли курсор прокручиваемым. Параметры:
- `stmt` - указатель на запрос;
- `usage_` - является ли курсор прокручиваемым (если конечно оператор возвращает курсор), если не задан (значение NULL), то возвращает текущее значение этого флага.

Функция `timeout()` устанавливает тайм-аут SQL запроса.

Функция `execute_direct()` подготавливает и выполняет SQL запрос. Функция возвращает указатель на набор данных (курсор), который можно обработать с помощью функций пакета `NANO$RSLT`. Параметры:
- `stmt` - указатель на запрос;
- `conn` - указатель на соединение;
- `query` - текст SQL запроса;
- `scrollable` - является ли курсор прокручиваемым (если конечно оператор возвращает курсор), если не задан (значение NULL), то используется поведения ODBC драйвера по умолчанию;
- `batch_operations` - количество пакетных операций. По умолчанию равно 1;
- `timeout` - тайм-аут SQL оператора.

Функция `just_execute_direct()` подготавливает и выполняет SQL запрос. Функция предназначена для выполнения SQL операторов не возвращающих данные (не открывающих курсор). Параметры:
- `stmt` - указатель на запрос;
- `conn` - указатель на соединение;
- `query` - текст SQL запроса;
- `batch_operations` - количество пакетных операций. По умолчанию равно 1;
- `timeout` - тайм-аут SQL оператора.


Функция `execute_()` выполняет подготовленный SQL запрос. Функция возвращает указатель на набор данных (курсор), который можно обработать с помощью функций пакета `NANO$RSLT`. Параметры:
- `stmt` - указатель на подготовленный запрос;
- `batch_operations` - количество пакетных операций. По умолчанию NANO$STMT равно 1;
- `timeout` - тайм-аут SQL оператора.


Функция `just_execute()` выполняет подготовленный SQL запрос. Функция предназначена для выполнения SQL операторов не возвращающих данные (не открывающих курсор). Параметры:
- `stmt` - указатель на подготовленный запрос;
- `batch_operations` - количество пакетных операций. По умолчанию равно 1;
- `timeout` - тайм-аут SQL оператора.

Функция `procedure_columns()` - возвращает описание выходного поля хранимой процедуры в виде набора данных `nano$rslt`. Параметры функции:
- `stmt` - указатель на запрос;
- `catalog_` - имя каталога которому принадлежит ХП;
- `schema_` - имя схемы в которой находится ХП;
- `procedure_` - имя хранимой процедуры;
- `column_` - имя выходного столбца ХП.

Функция `affected_rows()` возвращает количество строк затронутых SQL оператором. Эту функцию можно вызывать после выполнения оператора.

Функция `columns()` возвращает количество столбцов возвращаемых SQL запросом.

Функция `parameters()` возвращает количество параметров SQL запроса. Эту функцию можно вызывать только после подготовки SQL запроса.

Функция `parameter_size()` возвращает размер параметра в байтах. 
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра.

Функции семейства `bind_<type>...` связывают значение с параметром, если СУБД поддерживает пакетные операции cм. `execute()` параметр `batch_operations`, то количество передаваемых значений не ограничивается, в разумных пределах. В противном случае передается только первый введенный пакет значений. Само связывание происходит уже при вызове `execute()`.

Функция `bind_smallint()` привязывает значение типа SMALLINT к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_integer()` привязывает значение типа INTEGER к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_bigint()` привязывает значение типа BIGINT к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_float()` привязывает значение типа FLOAT к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_double()` привязывает значение типа DOUBLE PRECISION к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_varchar()` привязывает значение типа VARCHAR к SQL параметру. Используется для однобайтных кодировок.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра;
- `param_size` - размер параметра (строки).

Функция `bind_char()` привязывает значение типа CHAR к SQL параметру. Используется для однобайтных кодировок.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра;
- `param_size` - размер параметра (строки).

Функция `bind_u8_varchar()` привязывает значение типа VARCHAR к SQL параметру. Используется для строк в кодировке UTF8.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра;
- `param_size` - размер параметра (строки).

Функция `bind_u8_char()` привязывает значение типа VARCHAR к SQL параметру. Используется для строк в кодировке UTF8.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра;
- `param_size` - размер параметра (строки).

Функция `bind_blob()` привязывает значение типа BLOB к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_boolean()` привязывает значение типа BOOLEAN к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_date()` привязывает значение типа DATE к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_time()` привязывает значение типа TIME к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Замечание: при использовании `bind_time()` теряются миллисекунды в отличие от `bind_timestamp()`.

Функция `bind_timestamp()` привязывает значение типа TIMESTAMP к SQL параметру.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `value_` - значение параметра.

Функция `bind_null()` привязывает значение типа NULL к SQL параметру.
Нет принципиальной необходимости назначать значение NULL непосредственно для одного значения, если это не вытекает из логики обработки. Привязку NULL можно сделать и при вызове соответствующей  функции `bind_...` если ей передано значение NULL.
- `stmt` - указатель на подготовленный запрос;
- `parameter_index` - индекс параметра;
- `batch_size` - размер пакета (по умолчанию 1). Позволяет установить значение NULL для параметра с заданным индексом, сразу в нескольких элементах пакета.

Функция `convert_varchar()` преобразует значение типа VARCHAR в другую кодировку.
Параметры:
- `value_` - строковое значение;
- `from_` - кодировка из которой надо перекодировать строку;
- `to_` - кодировка в которую надо перекодировать строку;
- `convert_size` -  задаёт размер входного буфера для конвертирования (для скорости), для UTF8 например должен быть количество символов * 4. Размер выходного буфера всегда равен размеру объявления returns (можно своих наделать функций), изменение размера зависит от того откуда и куда конвертируется строковое значение: однобайтовая кодировка в многобайтовую - возможно увеличение относительно convert_size и наоборот – уменьшение, если многобайтовая кодировка преобразуется в однобайтовую. Усечение результата всегда происходит по размеру получаемого параметра.

Это вспомогательная функция, предназначенная для конвертирования строк в желаемую кодировку, поскольку не всегда другая сторона ODBC может ответить в правильной кодировке.

Функция `convert_char()` преобразует значение типа CHAR в другую кодировку.
Параметры:
- `value_` - строковое значение;
- `from_` - кодировка из которой надо перекодировать строку;
- `to_` - кодировка в которую надо перекодировать строку;
- `convert_size` - задаёт размер входного буфера для конвертирования (для скорости), для UTF8 например должен быть количество символов * 4. Размер выходного буфера всегда равен размеру объявления returns (можно своих наделать функций), изменение размера зависит от того откуда и куда конвертируется строковое значение: однобайтовая кодировка в многобайтовую - возможно увеличение относительно convert_size и наоборот – уменьшение, если многобайтовая кодировка преобразуется в однобайтовую. Усечение результата всегда происходит по размеру получаемого параметра.

Это вспомогательная функция, предназначенная для конвертирования строк в желаемую кодировку, поскольку не всегда другая сторона ODBC может ответить в правильной кодировке.

Функция `clear_bindings()` очищает текущий пакет значений для параметров. Вызов данной функции необходим при повторном использовании подготовленного оператора с новыми значениями.

Функция `describe_parameter()` заполняет буфер для описания параметра, то есть позволяет задать тип, размер и масштаб параметра.
- `stmt` - указатель на подготовленный запрос;
- `idx` - индекс параметра;
- `type_` - тип параметра;
- `size_` - размер (для строк);
- `scale_` - масштаб.

Функция `describe_parameters()` отправляет этот буфер описания параметров в ODBC, фактически описывает параметры. 

Функция `reset_parameters()` сбрасывает информацию о параметрах подготовленного запроса.


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

Пакет `NANO$RSLT` содержит функции для работы с набором данных возвращаемым SQL запросом.

Функция `valid()` возвращает является ли указатель на набор данных корректным.

Функция `release_()` освобождает указатель на набор данных.

Функция `connection()` возвращает указатель на соединение с базой данных.

Функция `rowset_size()` возвращает размер набора данных (сколько активных курсоров в наборе данных).

Функция `affected_rows()` возвращает количество строк затронутых оператором (выбрано в курсоре).

Функция `has_affected_rows()` возвращает есть ли хотя бы одна строка затронутая запросом.

Функция `rows_()` возвращает количество записей в открытом курсоре.

Функция `columns()` возвращает количество столбцов в текущем курсоре.

Функция `first_()` перемещает указатель текущего курсора на первую запись. Работает только для двунаправленных (прокручиваемых курсоров). Возвращает true если операция успешна.

Функция `last_()` перемещает указатель текущего курсора на последнюю запись. Работает только для двунаправленных (прокручиваемых курсоров). Возвращает true если операция успешна.

Функция `next_()` перемещает указатель текущего курсора на следующую запись. Возвращает true если операция успешна.

Функция `prior_()` перемещает указатель текущего курсора на предыдущую запись. Работает только для двунаправленных (прокручиваемых курсоров). Возвращает true если операция успешна.

Функция `move()` перемещает указатель текущего курсора на указанную запись. Работает только для двунаправленных (прокручиваемых курсоров). Возвращает true если операция успешна.
- `rslt` - указатель на подготовленный набор данных;
- `row_` - номер записи.

Функция `skip_()` перемещает указатель текущего курсора на указанное количество записей. Работает только для двунаправленных (прокручиваемых курсоров). Возвращает true если операция успешна.
- `rslt` - указатель на подготовленный набор данных;
- `row_` - сколько записей пропустить.

Функция `position_()` возвращает текущую позицию курсора.

Функция `at_end()` возвращает достиг ли указатель курсора последней записи.

Функция `get_smallint()` возвращает значение столбца типа SMALLINT. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `get_integer()` возвращает значение столбца типа INTEGER. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `get_bigint()` возвращает значение столбца типа BIGINT. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `get_float()` возвращает значение столбца типа FLOAT. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `get_double()` возвращает значение столбца типа DOUBLE PRECISION. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.


Функция `get_varchar()` возвращает значение столбца типа VARCHAR(256) CHARACTER SET NONE. Функция предназначена для однобайтовых кодировок.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Существует целое семейство этих функций с суффиксами. В зависимости от суффикса изменяется максимальный размер возвращаемой строки:
- `_s` - VARCHAR(64) CHARACTER SET NONE;
- `_l` - VARCHAR(1024) CHARACTER SET NONE;
- `_xl` - VARCHAR(8192) CHARACTER SET NONE;
- `_xxl` - VARCHAR(32765) CHARACTER SET NONE.

Скорость получения данных зависит от максимального размера строки. Так заполнение буфера для строки VARCHAR(32765) происходит в разы медленней, чем для строки VARCHAR(256), поэтому надо подбирать размер меньшего значения, если не нужно большего. 

Функция `get_char()` возвращает значение столбца типа CHAR(256) CHARACTER SET NONE. Функция предназначена для однобайтовых кодировок.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Существует целое семейство этих функций с суффиксами. В зависимости от суффикса изменяется максимальный размер возвращаемой строки:
- `_s` - CHAR(64) CHARACTER SET NONE;
- `_l` - CHAR(1024) CHARACTER SET NONE;
- `_xl` - CHAR(8192) CHARACTER SET NONE;
- `_xxl` - CHAR(32767) CHARACTER SET NONE.

Скорость получения данных зависит от максимального размера строки. Так заполнение буфера для строки CHAR(32767) происходит в разы медленней, чем для строки CHAR(256), поэтому надо подбирать размер меньшего значения, если не нужно большего. 

Функция `get_u8_varchar()` возвращает значение столбца типа VARCHAR(64) CHARACTER SET UTF8. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Существует целое семейство этих функций с суффиксами. В зависимости от суффикса изменяется максимальный размер возвращаемой строки:
- `_l` - VARCHAR(256) CHARACTER SET UTF8;
- `_xl` - VARCHAR(2048) CHARACTER SET UTF8;
- `_xxl` - VARCHAR(8191) CHARACTER SET UTF8.

Функция `get_u8_char()` возвращает значение столбца типа CHAR(64) CHARACTER SET UTF8. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Существует целое семейство этих функций с суффиксами. В зависимости от суффикса изменяется максимальный размер возвращаемой строки:
- `_l` - CHAR(256) CHARACTER SET UTF8;
- `_xl` - CHAR(2048) CHARACTER SET UTF8;
- `_xxl` - CHAR(8191) CHARACTER SET UTF8.

Функция `get_blob()` возвращает значение столбца типа BLOB.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `get_boolean()` возвращает значение столбца типа BOOLEAN.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `get_date()` возвращает значение столбца типа DATE.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `get_time()` возвращает значение столбца типа TIME.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `get_timestamp()` возвращает значение столбца типа TIMESTAMP.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.


Функция `convert_varchar()` преобразует значение типа VARCHAR в другую кодировку.
Параметры:
- `value_` - строковое значение;
- `from_` - кодировка из которой надо перекодировать строку;
- `to_` - кодировка в которую надо перекодировать строку;
- `convert_size` - задаёт размер входного буфера для конвертирования. См. `nano$stmt.convert_[var]char`.
  
Существует целое семейство этих функций с суффиксами. В зависимости от суффикса изменяется максимальный размер возвращаемой строки:
- `_s` - VARCHAR(64) CHARACTER SET NONE;
- `_l` - VARCHAR(1024) CHARACTER SET NONE;
- `_xl` - VARCHAR(8192) CHARACTER SET NONE;
- `_xxl` - VARCHAR(32765) CHARACTER SET NONE.

Функция `convert_char()` преобразует значение типа CHAR в другую кодировку.
Параметры:
- `value_` - строковое значение;
- `from_` - кодировка из которой надо перекодировать строку;
- `to_` - кодировка в которую надо перекодировать строку;
- `convert_size` -задаёт размер входного буфера для конвертирования. См. `nano$stmt.convert_[var]char`. 
  
Существует целое семейство этих функций с суффиксами. В зависимости от суффикса изменяется максимальный размер возвращаемой строки:
- `_s` - CHAR(64) CHARACTER SET NONE;
- `_l` - CHAR(1024) CHARACTER SET NONE;
- `_xl` - CHAR(8192) CHARACTER SET NONE;
- `_xxl` - CHAR(32765) CHARACTER SET NONE.  

Функция `unbind()` отвязывает буфер от заданного столбца. Особенность  передачи больших типов данных в некоторых реализациях ODBC.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `is_null()` возвращает является ли значение столбца значением NULL.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `is_bound()` проверяет привязан ли буфер значений для заданного столбца.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `column_()` возвращает номер столбца по его имени.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца.

Функция `column_name()` возвращает имя столбца по его индексу.
- `rslt` - указатель на подготовленный набор данных;
- `index_` - номер столбца `0..n-1`.

Функция `column_size()` возвращает размер столбца. Для строковых полей количество символов.

Функция `column_decimal_digits()` возвращает точность для числовых типов.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `column_datatype()` возвращает тип столбца. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `column_datatype_name()` возвращает имя типа столбца. 
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `column_c_datatype()` возвращает тип столбца как он закодирован в константах ODBC.
- `rslt` - указатель на подготовленный набор данных;
- `column_` - имя столбца или его номер `0..n-1`.

Функция `next_result()` переключает на следующий набор данных.
- `rslt` - указатель на подготовленный набор данных.

Функция `has_data()` возвращает есть ли данные в наборе данных.
- `rslt` - указатель на подготовленный набор данных.

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

Пакет `NANO$FUNC` содержит функции для работы с SQL запросами. Этот пакет является облегчённой версией пакета `NANO$STMT`. Особенность состоит в том, что выполняемые функции унаследовали поведение NANODBC без изменений и собственных доработок UDR в части обмена параметрами и значениями. Возможное направление использования: выполнение настроек ODBC соединения через выполнение SQL-команд (just_execute...), если поддерживается, логирование событий и т.п. простые операции.

Функция `execute_conn()` подготавливает и выполняет SQL запрос. Функция возвращает указатель на набор данных (курсор), который можно обработать с помощью функций пакета `NANO$RSLT`. Параметры:
- `conn` - указатель на соединение;
- `query` - текст SQL запроса;
- `batch_operations` - количество пакетных операций. По умолчанию равно 1;
- `timeout` - тайм-аут SQL оператора.

Функция `just_execute_conn()` подготавливает и выполняет SQL запрос. Функция предназначена для выполнения SQL операторов не возвращающих данные (не открывающих курсор). Указатель на объект SQL запрос не создается.  Параметры:
- `conn` - указатель на соединение;
- `query` - текст SQL запроса;
- `batch_operations` - количество пакетных операций. По умолчанию равно 1;
- `timeout` - тайм-аут SQL оператора.


Функция `execute_stmt()` выполняет подготовленный SQL запрос. Функция возвращает указатель на набор данных (курсор), который можно обработать с помощью функций пакета `NANO$RSLT`. Параметры:
- `stmt` - указатель на подготовленный запрос;
- `batch_operations` - количество пакетных операций. По умолчанию NANO$STMT равно 1.

Функция `transact_stmt()` -  выполняет ранее подготовленный SQL запрос, стартуя и завершая собственную (автономную) транзакцию. Функция возвращает указатель на набор данных (курсор), который можно обработать с помощью функций пакета `NANO$RSLT`. Параметры:
- `stmt` - указатель на подготовленный запрос;
- `batch_operations` - количество пакетных операций. По умолчанию NANO$STMT равно 1.

Функция `just_transact_stmt()` - выполняет ранее подготовленный SQL запрос, стартуя и завершая собственную (автономную) транзакцию. Функция предназначена для выполнения SQL операторов не возвращающих данные (не открывающих курсор). Параметры:
- `stmt` - указатель на подготовленный запрос;
- `batch_operations` - количество пакетных операций. По умолчанию NANO$STMT равно 1.

Функция `prepare_stmt()` подготавливает SQL запрос.  Параметры:
- `stmt` - указатель на запрос;
- `query` - текст SQL запроса;
- `timeout` - тайм-аут SQL оператора.

## Примеры

### Выборка данных из таблицы Postgresql

В этом примере производится выборка из базы данных Postgresql. Текст блока снабжён комментариями для понимания происходящего.

```sql
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
```

### Вставка данных в таблицу Postgresql

В этом примере производится вставка новой строки в таблицу. Текст блока снабжён комментариями для понимания происходящего.

```sql
EXECUTE BLOCK
RETURNS (
  aff_rows integer
)
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
    nano$stmt.bind_integer(stmt, 0, 4);
    nano$stmt.bind_u8_varchar(stmt, 1, 'Строка 4', 4 * 20);
    -- выполняем оператор INSERT
    nano$stmt.just_execute(stmt);
    -- получаем количество затронутых строк
    aff_rows = nano$stmt.affected_rows(stmt);
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

  suspend;
END
```

### Пакетная вставка данных в таблицу Postgresql

Если СУБД и ODBC драйвер поддерживают пакетное выполнение запросов, то можно использовать batch операции.

```sql
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
```

### Использование транзакций

```sql
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
```
