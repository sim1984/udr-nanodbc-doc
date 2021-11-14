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


