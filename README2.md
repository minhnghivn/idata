### Overview
Cấu trúc file YAML như sau:
```sh
table1:
- field: field_name
  validations: can be more than one
    - rule: (not null | matches | consistent by | cross references | unique | custom query | reverse query)
      code: custom error code
      error: custom error message
      solution: solution if this is encountered
      impact: the impact this has
table2:
- field: vendor_code, vendor_name
  validations:
    - rule: unique
      code: 501
      error: [vendor_code, vendor_name] must be unique
      solution: skip
      impact: blah blah
```

#### Explain:
+ Một `table` có 1 hoặc nhiều `field`
+ Một `field` có 1 section `validations` chứa một hoặc nhiều rules
+ Mỗi rule chứa `rule` (required) và `code`, `error`, `solution`, `impact`, `priority` tương ứng (optional)
+ Rule: viết theo format covered bên dưới
+ Các field khác free text trên cùng 1 line, dùng \n làm dấu cách dòng
+ Giá trị của field có thể là một hoặc tập gồm nhiều field name, separated by comma

## Writing rules:
Supported rules include:

| Rule | Description | Example |
| ---- | ----------- | ------- |
| not null | Giá trị của field tương ứng không được rỗng |  |
| unique | Giá trị của field tương ứng phải unique trong table |  |
| matches "/REGEXP/" | Giá trị của field phải thỏa format định nghĩa bởi REGEXP | |
| not matches "/REGEXP/" | Reverse counterpart của match | |
| consistent by "REF" | Field phải consistent với REF | |
| cross references "TABLE.FIELD" | Giá trị của field phải reference tới một field khác TABLE.FIELD | |
| custom query | Dùng custom SQL (trong trường hợp business phức tạp không thể biểu diễn bằng cách rule khác) | |
| reverse query | Reverse counterpart của | |

## Others
TBD
