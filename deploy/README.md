# deploy.ps1

The Powershell script in this folder is one I use (in some form) in nearly all of my personal projects. It is how I deploy all of my scripts for a database, both locally and up through the environments for a release. It accepts four arguments:

- Database : This is the name of the database in the repo, and needs to match a folder under the parent folder of this script.
- Environment : This is one of 'dev', 'test', 'staging', or 'prod'. Currently, the only effective use of this is that it will run unit tests in only 'dev' or 'test' environments.
- ServerName : The name of the target SQL Server instance.
- DatabaseName : The name of the target SQL Server database.

The script assumes a specific folder structure under the main database folder:

- The first level is folders by schema name.
- The second level is folders by object type.

The script runs all .sql files that it discovers within this folder structure in the following order:

1. All files that begin with an underscore.
2. All files in a 'table' folder under each schema folder. The intention is for each file to also hold all index definitions for that table. 
3. All files in a 'data' folder under each schema folder. The intention is for this to contain files for adding enumeration values, bootstrap data, etc.
4. All files in a 'procedure' folder under each schema folder.
5. Depending on the Environment, all files in a 'test' folder under each schema folder.

### Notes ###

- The script will halt if it encounters an error. The intention for scripts in the test folder is for them to `THROW` an error if a validation check fails.
- It currently only uses Windows authentication, not SQL Server authentication.
- All files are assumed to be idempotent. For example, procedure scripts should all use `CREATE OR ALTER <procedure_name>` syntax.
- For table scripts, the expectation is that the script contains the current `CREATE TABLE` statement, as well as all `ALTER TABLE` scripts necessary for sufficient backward compatibility.
- The files in each folder are executed in alphabetical order.
- See https://dev.azure.com/downshiftdata/_git/SearchOverflow for an example.

### TODO ###

- Add more folder types *in the best possible order*.
- Add the ability to run only specific scripts (e.g. modified after a certain date).
- Add SQL Server authentication.