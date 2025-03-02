dbcc freeproccache
go

select *
from sys.dm_exec_cached_plans
go

--Display all indexes along with key columns, included columns and index type
declare @TempTable as table (
	SchemaName varchar(100)
	,ObjectID int
	,TableName varchar(100)
	,IndexID int
	,IndexName varchar(100)
	,ColumnID int
	,column_index_id int
	,ColumnNames varchar(500)
	,IncludeColumns varchar(500)
	,NumberOfColumns int
	,IndexType varchar(20)
	,LastColRecord int
	);

with CTE_Indexes (
	SchemaName
	,ObjectID
	,TableName
	,IndexID
	,IndexName
	,ColumnID
	,column_index_id
	,ColumnNames
	,IncludeColumns
	,NumberOfColumns
	,IndexType
	)
as (
	select s.name
		,t.object_id
		,t.name
		,i.index_id
		,i.name
		,c.column_id
		,ic.index_column_id
		,case ic.is_included_column
			when 0
				then CAST(c.name as varchar(5000))
			else ''
			end
		,case ic.is_included_column
			when 1
				then CAST(c.name as varchar(5000))
			else ''
			end
		,1
		,i.type_desc
	from sys.schemas as s
	join sys.tables as t
		on s.schema_id = t.schema_id
	join sys.indexes as i
		on i.object_id = t.object_id
	join sys.index_columns as ic
		on ic.index_id = i.index_id and ic.object_id = i.object_id
	join sys.columns as c
		on c.column_id = ic.column_id and c.object_id = ic.object_id and ic.index_column_id = 1
	
	union all
	
	select s.name
		,t.object_id
		,t.name
		,i.index_id
		,i.name
		,c.column_id
		,ic.index_column_id
		,case ic.is_included_column
			when 0
				then CAST(cte.ColumnNames + ', ' + c.name as varchar(5000))
			else cte.ColumnNames
			end
		,case 
			when ic.is_included_column = 1 and cte.IncludeColumns != ''
				then CAST(cte.IncludeColumns + ', ' + c.name as varchar(5000))
			when ic.is_included_column = 1 and cte.IncludeColumns = ''
				then CAST(c.name as varchar(5000))
			else ''
			end
		,cte.NumberOfColumns + 1
		,i.type_desc
	from sys.schemas as s
	join sys.tables as t
		on s.schema_id = t.schema_id
	join sys.indexes as i
		on i.object_id = t.object_id
	join sys.index_columns as ic
		on ic.index_id = i.index_id and ic.object_id = i.object_id
	join sys.columns as c
		on c.column_id = ic.column_id and c.object_id = ic.object_id
	join CTE_Indexes cte
		on cte.Column_index_ID + 1 = ic.index_column_id
			--JOIN CTE_Indexes cte ON cte.ColumnID + 1 = ic.index_column_id  
			and cte.IndexID = i.index_id and cte.ObjectID = ic.object_id
	)
insert into @TempTable
select *
	,RANK() over (
		partition by ObjectID
		,IndexID order by NumberOfColumns desc
		) as LastRecord
from CTE_Indexes as cte;

select SchemaName
	,TableName
	,IndexName
	,ColumnNames
	,IncludeColumns
	,IndexType
from @TempTable
where LastColRecord = 1
order by objectid
	,TableName
	,indexid
	,IndexName
go

with Columnsqry
as (
	select name
		,ic.object_id
		,ic.index_id
		,is_included_column
		,ic.key_ordinal
	from sys.index_columns IC
		,sys.columns c
	where ic.object_id = c.object_id and ic.column_id = c.column_id
	)
	,IndexQry
as (
	select I.object_id
		,I.index_id
		,(
			select stuff((
						select ',' + name as [text()]
						from Columnsqry q
						where q.object_id = I.object_id and q.index_id = i.index_id and q.is_included_column = 0
						order by q.key_ordinal
						for xml path('')
						), 1, 1, '')
			) Keys
		,(
			select stuff((
						select ',' + name as [text()]
						from Columnsqry q
						where q.object_id = I.object_id and q.index_id = i.index_id and q.is_included_column = 1
						for xml path('')
						), 1, 1, '')
			) Included
	from Columnsqry q
		,sys.indexes I
		,sys.objects o
	where q.object_id = I.object_id and q.index_id = i.index_id and o.object_id = I.object_id and O.type not in ('S', 'IT')
	group by I.object_id
		,I.index_id
	)
select IQ.object_id
	,o.name as [table]
	,IQ.Index_id
	,I.name as [Index]
	,I.type_desc
	,keys
	,included
	,is_unique
	,fill_factor
	,is_padded
	,has_filter
	,filter_definition
from IndexQry IQ
	,Sys.objects o
	,sys.indexes I
where IQ.object_id = o.object_id and IQ.object_id = I.object_id and IQ.Index_id = I.index_id
go

-- =============================================
-- Author:        Dennes Torres
-- Create date: 29/03/2015
-- Description:    Fornece informaÃ§Ãµes mais completas sobre
--                 indices, com suas chaves, included columns
--                 e outras informaÃ§Ãµes
-- =============================================
create function IndexInformation ()
returns table
as
return (
		with Columnsqry as (
				select name
					,ic.object_id
					,ic.index_id
					,is_included_column
					,ic.key_ordinal
				from sys.index_columns IC
					,sys.columns c
				where ic.object_id = c.object_id and ic.column_id = c.column_id
				)
			,IndexQry as (
				select I.object_id
					,I.index_id
					,(
						select stuff((
									select ',' + name as [text()]
									from Columnsqry q
									where q.object_id = I.object_id and q.index_id = i.index_id and q.is_included_column = 0
									order by q.key_ordinal
									for xml path('')
									), 1, 1, '')
						) Keys
					,(
						select stuff((
									select ',' + name as [text()]
									from Columnsqry q
									where q.object_id = I.object_id and q.index_id = i.index_id and q.is_included_column = 1
									for xml path('')
									), 1, 1, '')
						) Included
				from Columnsqry q
					,sys.indexes I
					,sys.objects o
				where q.object_id = I.object_id and q.index_id = i.index_id and o.object_id = I.object_id and O.type not in ('S', 'IT')
				group by I.object_id
					,I.index_id
				)
		select IQ.object_id
			,o.name as [table]
			,IQ.Index_id
			,I.name as [Index]
			,I.type_desc
			,keys
			,included
			,is_unique
			,fill_factor
			,is_padded
			,has_filter
			,filter_definition
		from IndexQry IQ
			,Sys.objects o
			,sys.indexes I
		where IQ.object_id = o.object_id and IQ.object_id = I.object_id and IQ.Index_id = I.index_id
		)
go


