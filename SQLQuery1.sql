SELECT name AS object_name 
  ,SCHEMA_NAME(schema_id) AS schema_name
  ,type_desc
  ,create_date
  ,modify_date
  ,object_id
FROM sys.objects
WHERE modify_date > GETDATE() - 10
ORDER BY modify_date; 
