SELECT name, 
       type
  FROM dbo.sysobjects
 WHERE (type = 'P')