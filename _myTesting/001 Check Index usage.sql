select OBJECT_NAME(A.[OBJECT_ID]) as [OBJECT NAME]
	,I.[NAME] as [INDEX NAME]
	,A.LEAF_INSERT_COUNT
	,A.LEAF_UPDATE_COUNT
	,A.LEAF_DELETE_COUNT
from SYS.DM_DB_INDEX_OPERATIONAL_STATS(null, null, null, null) A
inner join SYS.INDEXES as I
	on I.[OBJECT_ID] = A.[OBJECT_ID] and I.INDEX_ID = A.INDEX_ID
where OBJECTPROPERTY(A.[OBJECT_ID], 'IsUserTable') = 1
go

select OBJECT_NAME(S.[OBJECT_ID]) as [OBJECT NAME]
	,I.[NAME] as [INDEX NAME]
	,USER_SEEKS
	,USER_SCANS
	,USER_LOOKUPS
	,USER_UPDATES
from SYS.DM_DB_INDEX_USAGE_STATS as S
inner join SYS.INDEXES as I
	on I.[OBJECT_ID] = S.[OBJECT_ID] and I.INDEX_ID = S.INDEX_ID
where OBJECTPROPERTY(S.[OBJECT_ID], 'IsUserTable') = 1
go

select o.name
	,ips.partition_number
	,ips.index_type_desc
	,ips.record_count
	,ips.avg_record_size_in_bytes
	,ips.min_record_size_in_bytes
	,ips.max_record_size_in_bytes
	,ips.page_count
	,ips.compressed_page_count
from sys.dm_db_index_physical_stats(DB_ID(), null, null, null, 'DETAILED') ips
inner join sys.objects o
	on o.object_id = ips.object_id
order by record_count desc;
go

select *
from sys.dm_db_index_physical_stats(null, null, null, null, null);
go

select OBJECT_NAME(i.object_id) as TableName
	,i.name as IndexName
	,c.name as ColumnName
from sys.indexes i
inner join sys.index_columns ic
	on i.object_id = ic.object_id and i.index_id = ic.index_id
inner join sys.columns c
	on ic.object_id = c.object_id and ic.column_id = c.column_id
where OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
order by TableName
	,IndexName
	,ic.key_ordinal;
go

select i.[name] as index_name
	,substring(column_names, 1, len(column_names) - 1) as [columns]
	,case 
		when i.[type] = 1
			then 'Clustered index'
		when i.[type] = 2
			then 'Nonclustered unique index'
		when i.[type] = 3
			then 'XML index'
		when i.[type] = 4
			then 'Spatial index'
		when i.[type] = 5
			then 'Clustered columnstore index'
		when i.[type] = 6
			then 'Nonclustered columnstore index'
		when i.[type] = 7
			then 'Nonclustered hash index'
		end as index_type
	,case 
		when i.is_unique = 1
			then 'Unique'
		else 'Not unique'
		end as [unique]
	,schema_name(t.schema_id) + '.' + t.[name] as table_view
	,case 
		when t.[type] = 'U'
			then 'Table'
		when t.[type] = 'V'
			then 'View'
		end as [object_type]
from sys.objects t
inner join sys.indexes i
	on t.object_id = i.object_id
cross apply (
	select col.[name] + ', '
	from sys.index_columns ic
	inner join sys.columns col
		on ic.object_id = col.object_id and ic.column_id = col.column_id
	where ic.object_id = t.object_id and ic.index_id = i.index_id
	order by key_ordinal
	for xml path('')
	) D(column_names)
where t.is_ms_shipped <> 1 and index_id > 0
order by i.[name]
go

select OBJECT_NAME(i.[object_id]) TableName
	,i.[name] IndexName
	,(
		select STRING_AGG(cast(c.name as varchar), ', ')
		from sys.index_columns ic
		join sys.columns c
			on ic.object_id = c.object_id and ic.column_id = c.column_id
		where ic.object_id = i.object_id and ic.index_id = i.index_id and ic.is_included_column = 0
		) KeyColumns
	,(
		select STRING_AGG(cast(c.name as varchar), ', ')
		from sys.index_columns ic
		join sys.columns c
			on ic.object_id = c.object_id and ic.column_id = c.column_id
		where ic.object_id = i.object_id and ic.index_id = i.index_id and ic.is_included_column = 1
		) IncludeColumns
from sys.indexes i
where 1 = 1
-- and OBJECT_NAME(i.[object_id]) = 'MyTable'
--and i.name like 'IX_MyIndex'
--and i.is_primary_key = 0
group by OBJECT_NAME(i.[object_id])
	,i.name
	,i.object_id
	,i.index_id
order by tableName
	,i.name
go

select OBJECT_NAME(i.[object_id]) TableName
	,i.[name] IndexName
	,c.[name] ColumnName
	,ic.is_included_column
	,i.index_id
	,i.type_desc
	,i.is_unique
	,i.data_space_id
	,i.ignore_dup_key
	,i.is_primary_key
	,i.is_unique_constraint
from sys.indexes i
join sys.index_columns ic
	on ic.object_id = i.object_id and i.index_id = ic.index_id
join sys.columns c
	on ic.object_id = c.object_id and ic.column_id = c.column_id
order by tableName
	,ic.index_id
	,ic.index_column_id
go


