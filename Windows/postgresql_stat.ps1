# �������� ���������� ������� PostgreSQL �� ������ Zabbix

# ������ ��� ������������ ����� ������� PostgreSQL
$PsqlExec = 'E:\PostgreSQL\9.4.2-1.1C\bin\psql'


function PSql($SQLStr){
# ���������� �������� ������� psql. ���������: 1 - ������ SQL-��������

 # ���������� ��������:
 #  quiet - ��� ���������, ������ ���������� �������;
 #  field-separator= - ����������� �����;
 #  no-align - ����� ������������� �������;
 #  tuples-only - ������ ������ ����������
 $RespStr = & $PsqlExec --quiet --field-separator=" " --no-align --tuples-only --host=127.0.0.1 --username=zabbix --command="$SQLStr;" template1 2>&1
 # ���������� �������� ������� - ������� ������ ����������
 if( $? ){ return $RespStr }
 # ���������� ���������� - ������� ������� ������� - '�� ��������'
 Write-Host 0
 # ����� �� ��������
 exit 1
}


# ��������� ������ ������ ��
$DBStr = PSql "SELECT datname FROM pg_stat_database where datname not like 'template%'"

# ���� �������� ��������� ������ ����������� ��
if( $args[0] -and $args[0] -eq 'db' ){
 # ���������� ������ ������ �� � ������ JSON
 $DBStr = $DBStr -split '`n' -join '"},{"{#DBNAME}":"'
 if( $DBStr ){ $DBStr = "{`"{#DBNAME}`":`"" + $DBStr + "`"}" }
 $DBStr = "{`"data`":[" + $DBStr + "]}"
 # ����� JSON-������ ��
 Write-Host -NoNewLine $DBStr

# �������� ������
}else{
 # ������ SQL-��������
 $SelectsStr = '';
 # ���������� � ������ �������� ���������� �� ��
 # ������� �������� ���� �� ������� pg_stat_database ��� ��
 'numbackends', 'deadlocks', 'tup_returned', 'tup_fetched', 'tup_inserted', 'tup_updated',`
  'tup_deleted', 'temp_files', 'temp_bytes', 'blk_read_time', 'blk_write_time',`
  'xact_commit', 'xact_rollback' | Where { $SelectsStr += "select '- postgresql." + $_ +
  "['||datname||'] '||" + $_ + " from pg_stat_database where datname not like 'template%' union " }
 # ����������� ������� ��� ��
 $DBStr -split '`n' | Where { $SelectsStr += "select '- postgresql.size[" + $_ +
  "] '||pg_database_size('" + $_ + "') union select '- postgresql.cache[" + $_ +
  "] '||cast(blks_hit/(blks_read+blks_hit+0.000001)*100.0 as numeric(5,2)) from pg_stat_database where datname='" +
  $_ + "' union select '- postgresql.success[" + $_ +
  "] '||cast(xact_commit/(xact_rollback+xact_commit+0.000001)*100.0 as numeric(5,2)) from pg_stat_database where datname='" +
  $_ + "' union "
  }
 
 # ���������� � ������ �������� ����� ����������
 # ������� �������� ���������� �� ������� pg_stat_activity: '��������' = '������'
 @{
  'active'   = "state='active'";
  'idle'     = "state='idle'";
  'idle_tx'  = "state='idle in transaction'";
  'server'   = '1=1';
  'waiting'  = "waiting='true'";
 }.GetEnumerator() | Where { $SelectsStr += "select '- postgresql.connections." + $_.Key +
  " '||count(*) from pg_stat_activity where " + $_.Value + " union " }

 # ������� �������� ���� �� ������� pg_stat_activity
 'buffers_alloc', 'buffers_backend', 'buffers_backend_fsync', 'buffers_checkpoint',`
  'buffers_clean', 'checkpoints_req', 'checkpoints_timed', 'maxwritten_clean' |
  Where { $SelectsStr += "select '- postgresql." + $_ + " '||" + $_ +
  " from pg_stat_bgwriter union " }

 # ������� ���������� ��������� �������� �� ������� pg_stat_activity: '��������' = '������'
 @{
  'slow.dml'     = "~* '^(insert|update|delete)'";
  'slow.queries' = "ilike '%'";
  'slow.select'  = "ilike 'select%'";
 }.GetEnumerator() | Where { $SelectsStr += "select '- postgresql." + $_.Key +
  " '||count(*) from pg_stat_activity where state='active' and now()-query_start>'5 sec'::interval and query " +
  $_.Value + " union " }

 # ������������ ���������� ����������
 $SelectsStr += "select '- postgresql.connections.max '||setting::int from pg_settings where name='max_connections'"

 # ���������� �������� � �������� ������ ������ ������� Zabbix. ��������� zabbix_sender:
 #  --config      ���� ������������ ������;
 #  --host        ��� ���� ���� �� ������� Zabbix;
 #  --input-file  ���� ������('-' - ����������� ����)
 PSql $SelectsStr | c:\Scripts\zabbix_sender.exe --config "c:\Scripts\zabbix_agentd_win.conf" --host "DNS.���.�������" --input-file - 2>&1 | Out-Null

 # ������� ������� ������� - '��������'
 Write-Host 1
}
