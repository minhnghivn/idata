### Overview
File dùng cho validation criteria có cấu trúc chung như sau:
```yaml
table:
- field: field1, field2, etc.
  validations:
    - rule:
      code:
      error:
      impact:
      solution:
```

##### Explain:
+ Một `table` có một hoặc nhiều `field`
+ Một `field` có một section `validations` chứa một hoặc nhiều rules
+ Mỗi rule chứa `rule` (required) và `code`, `error`, `solution`, `impact`, `priority` tương ứng (optional)
+ Rule: viết theo format covered bên dưới
+ Các field khác free text trên cùng 1 line, dùng \n làm dấu cách dòng
+ Giá trị của field có thể là một hoặc tập gồm nhiều field name, separated by comma

## Writing rules
Supported rules include:

| Rule | Description | Example |
| ---- | ----------- | ------- |
| `not null` | Giá trị của field tương ứng không được rỗng |  |
| `unique` | Giá trị của field tương ứng phải unique trong table |  |
| `matches "/regexp/"` | Giá trị của field phải thỏa format định nghĩa bởi `regexp` | |
| `not matches "/regexp/"` | Reverse counterpart của `matches` | |
| `consistent by "ref"` | Giá trị của field tương ứng phải consistent với `ref` | |
| `cross references "table.field"` | Giá trị của field phải reference tới một field khác `table.field` | |
| `custom query "query"` | Dùng custom SQL `query` (trong trường hợp business phức tạp không thể biểu diễn bằng các rule khác) | |
| `reverse query "query"` | Reverse counterpart của `custom query` | |

Query the validation log
=========
Look at the illustration below for the schema of `log` table
![log schema](https://s3-ap-southeast-1.amazonaws.com/mycdn1104/log.png)
#### Some common queries
List of IDL tables
```
.tables
```
List of tables and errors found
```
SELECT distinct table_name, error FROM log;
```
List of tables, errors and item count for every error
```
SELECT table_name, error, count(*) FROM log GROUP BY table_name, error;
```
List of tables and error count
```
SELECT table_name, count(DISTINCT error) FROM log GROUP BY table_name;
```
Delete `vendors` with a particular error:
```
DELETE FROM vendors WHERE rowid IN (SELECT id FROM log WHERE error = 'invalid vendor name' AND table_name = 'vendors');
```
Delete *all* `vendors` with error:
```
DELETE FROM vendors WHERE rowid IN (SELECT id FROM log WHERE table_name = 'vendors');
```

## Others
TBD
