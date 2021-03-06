/****** Object:  StoredProcedure [dbo].[sp_search_text_in_target_tables]    Script Date: 2018-06-08 AM 9:16:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[sp_search_text_to_target_tables] (@schema    SYSNAME, @SearchStr NVARCHAR(100)) 
AS 
  BEGIN 
      /* Declare result table variables 결과 조회 테이블 변수 선언 */ 
      /*DECLARE @Results TABLE 
        ( 
           columnname  NVARCHAR(370), 
           columnvalue NVARCHAR(3630), 
           pk_key1     NVARCHAR(3630), 
           pk_key2     NVARCHAR(3630), 
           pk_key3     NVARCHAR(3630), 
           pk_key4     NVARCHAR(3630), 
           pk_key5     NVARCHAR(3630) 
        )*/

      SET nocount ON

      DECLARE @TableName  NVARCHAR(110), 
              @ColumnName NVARCHAR(110), 
              @SearchStr2 NVARCHAR(110),
              @result int,
              @sql NVARCHAR(500)
              
      /* column variables for each table's pk info (각 테이블의 PK 정보 저장용 컬럼 변수) */      
      DECLARE @Pk_Key1 NVARCHAR(3630), 
              @Pk_Key2 NVARCHAR(3630), 
              @Pk_Key3 NVARCHAR(3630), 
              @Pk_Key4 NVARCHAR(3630), 
              @Pk_Key5 NVARCHAR(3630)

      SET @SearchStr2 = Quotename(@SearchStr + '%', '''') 
      PRINT '------ PROCEDURE START >>>>>>> ' + CONVERT(CHAR(19), getdate(), 120)
      
       /* Declare cursor for scanning tables on whole database (host 데이터 조회 대상 테이블 스캔용 커서 선언) */ 
      DECLARE table_corsor CURSOR FOR 
        SELECT target_name 
        FROM   host_target_table_tmp 
        ORDER  BY idx

      OPEN table_corsor

      FETCH next FROM table_corsor INTO @TableName

      WHILE ( @@FETCH_STATUS = 0 ) 
        BEGIN

            /* Setting each table's pk info (max 5) 각 테이블의 PK 정보 셋팅 (최대 5개 한정) */ 
            SET @Pk_Key1 = (SELECT COALESCE(max(a.COLUMN_NAME), 'null') AS column_name 
                                FROM (
                                  SELECT COLUMN_NAME
                                  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                                  WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                                  AND table_name = @TableName  
                                  AND ordinal_position = 1
                                  ) a 
                             ) 
            SET @Pk_Key2 = (SELECT COALESCE(max(a.COLUMN_NAME), 'null') AS column_name 
                                FROM (
                                  SELECT COLUMN_NAME
                                  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                                  WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                                  AND table_name = @TableName  
                                  AND ordinal_position = 2
                                  ) a 
                             )
            SET @Pk_Key3 = (SELECT COALESCE(max(a.COLUMN_NAME), 'null') AS column_name 
                                FROM (
                                  SELECT COLUMN_NAME
                                  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                                  WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                                  AND table_name = @TableName  
                                  AND ordinal_position = 3
                                  ) a 
                             ) 
            SET @Pk_Key4 = (SELECT COALESCE(max(a.COLUMN_NAME), 'null') AS column_name 
                                FROM (
                                  SELECT COLUMN_NAME
                                  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                                  WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                                  AND table_name = @TableName  
                                  AND ordinal_position = 4
                                  ) a 
                             )
            SET @Pk_Key5 = (SELECT COALESCE(max(a.COLUMN_NAME), 'null') AS column_name 
                                FROM (
                                  SELECT COLUMN_NAME
                                  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                                  WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
                                  AND table_name = @TableName 
                                  AND ordinal_position = 5
                                  ) a 
                             )
            SET @ColumnName = ''

            /* start loop for scanning table's columns 각 테이블 컬럼 스캔 루프 시작*/ 
            WHILE ( @ColumnName IS NOT NULL ) 
              BEGIN 
                  SET @ColumnName = (SELECT Min(Quotename(column_name)) 
                                     FROM   information_schema.columns 
                                     WHERE  table_schema = @schema 
                                            AND table_name = @TableName 
                                            AND data_type IN ('char','nchar','nvarchar','text','varchar')  
                                            AND Quotename(column_name) > @ColumnName)

                  /* Create select queries with the columns scanned and save 스캔한 컬럼으로 select문 생성 및 해당 결과 저장*/ 
                  IF @ColumnName IS NOT NULL 
                    BEGIN 
                        SET @sql = N'SELECT @chk_col= CASE WHEN max(cast('+@ColumnName+'as varchar(max))) IS NULL THEN 1 ELSE 0 END FROM ' + @TableName + ' WITH (NOLOCK) ' + ' WHERE ' + @ColumnName  + ' LIKE ' + @SearchStr2
                        EXEC sp_executesql @sql, N'@chk_col int output',@chk_col=@result OUTPUT
                        --print @result
                        /*INSERT INTO @Results*/ 
                        /* If there's no row, skip to excute queries 해당 컬럼의 값이 없으면 쿼리 실행 생략*/
                        IF @result != 1
                            BEGIN
                                EXEC (  'SELECT ''' + @TableName + '.' + @ColumnName + ''' as columnname, ' +  @ColumnName  + ' as columnvalue,
                                concat(cast('''+@Pk_Key1+''' as varchar(100))+'' || '', '+ @Pk_Key1+') as Pk_Key1,
                                concat(cast('''+@Pk_Key2+''' as varchar(100))+'' || '', '+ @Pk_Key2+') as Pk_Key2,
                                concat(cast('''+@Pk_Key3+''' as varchar(100))+'' || '', '+ @Pk_Key3+') as Pk_Key3,
                                concat(cast('''+@Pk_Key4+''' as varchar(100))+'' || '', '+ @Pk_Key4+') as Pk_Key4,
                                concat(cast('''+@Pk_Key5+''' as varchar(100))+'' || '', '+ @Pk_Key5+') as Pk_Key5
                                FROM ' + @TableName + ' WITH (NOLOCK) ' + ' WHERE ' + @ColumnName  + ' LIKE ' + @SearchStr2 ) 
                            END
                    END 
              END

            FETCH next FROM table_corsor INTO @TableName 
        END

      /* select the results 결과 조회 */ 
      /*SELECT columnname, 
             columnvalue, 
             pk_key1, 
             pk_key2, 
             pk_key3, 
             pk_key4, 
             pk_key5 
      FROM   @Results*/

      /*cursor close*/ 
      CLOSE table_corsor; 
      DEALLOCATE table_corsor; 
      
      PRINT '------ PROCEDURE FINISHED >>>>>>> ' + CONVERT(CHAR(19), getdate(), 120)
  END
GO
