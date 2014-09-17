### Overview
File dùng cho validation criteria có cấu trúc chung như sau:
```yaml
table1:
- field: field_name
  validations: can be more than one
    - rule: (not null|matches|consistent by|cross references|unique|custom query|reverse query)
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
+ Một `table` có một hoặc nhiều `field`
+ Một `field` có một section `validations` chứa một hoặc nhiều rules
+ Mỗi rule chứa `rule` (required) và `code`, `error`, `solution`, `impact`, `priority` tương ứng (optional)
+ Rule: viết theo format covered bên dưới
+ Các field khác free text trên cùng 1 line, dùng \n làm dấu cách dòng
+ Giá trị của field có thể là một hoặc tập gồm nhiều field name, separated by comma

## Writing rules:
Supported rules include:

| Rule | Description | Example |
| ---- | ----------- | ------- |
| `not null` | Giá trị của field tương ứng không được rỗng |  |
| `unique` | Giá trị của field tương ứng phải unique trong table |  |
| `matches` "/regexp/" | Giá trị của field phải thỏa format định nghĩa bởi `regexp` | |
| `not matches` "/regexp/" | Reverse counterpart của `matches` | |
| `consistent by` "ref" | Giá trị của field tương ứng phải consistent với `ref` | |
| `cross references` "table.field" | Giá trị của field phải reference tới một field khác `table.field` | |
| `custom query` | Dùng custom SQL (trong trường hợp business phức tạp không thể biểu diễn bằng các rule khác) | |
| `reverse query` | Reverse counterpart của | |

## Others
TBD
