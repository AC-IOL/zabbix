# �������� ���������� ������� RabbitMQ �� ������ Zabbix


function RabbitMQAPI($Query){
# ������ � API PabbitMQ. ���������: 1 - ������ ���������� ������� API

 # ������ Uri API PabbitMQ
 $uri = New-Object System.Uri("https://127.0.0.1:15672/api/$Query");

 # �������������� �������������� '%2f' � ������ '/'
 # ������������� ������� Uri
 $uri.PathAndQuery | Out-Null
 $flagsField = $uri.GetType().GetField("m_Flags", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)
 # remove flags Flags.PathNotCanonical and Flags.QueryNotCanonical
 $flagsField.SetValue($uri, [UInt64]([UInt64]$flagsField.GetValue($uri) -band (-bnot 0x30)))

 $RespStr = $wc.DownloadString($uri) | ConvertFrom-Json
 # ���������� ������� ������� - ������� ������ ����������
 if( $? ){ return $RespStr }
 # ���������� ���������� - ������� ������� ������� - '�� ��������'
 Write-Host 0
 # ����� �� ��������
 exit 1
}


# ��������� ������ - ��������� �������
$OutputEncoding = [Console]::OutputEncoding
# ���������� �������� ����������� �������
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
# ��������� ��� ��������� ������ ���������������� �� URI ��������
$wc = New-Object System.Net.WebClient
# ������ ��������������
$wc.Credentials = New-Object System.Net.NetworkCredential('������������_�����������', '������_�����������')

# ��������� ������ ������ ��������
$QueuesStr = RabbitMQAPI 'queues?columns=name'

# ���� �������� ��������� ������ ����������� ��������
if( $args[0] -and $args[0] -eq 'queues' ){
 # ���������� ������ ������ �������� � ������ JSON
 $QueuesStr = $QueuesStr.name -split '`n' -join '"},{"{#QUEUENAME}":"'
 if( $QueuesStr ){ $QueuesStr = "{`"{#QUEUENAME}`":`"" + $QueuesStr + "`"}" }
 $QueuesStr = "{`"data`":[" + $QueuesStr + "]}"
 # ����� JSON-������ ��������
 Write-Host -NoNewLine $QueuesStr

# �������� ������
}else{
 # ������ ������
 $OutStr = ''
 # ����� ����������
 $Overview = RabbitMQAPI 'overview?columns=message_stats,queue_totals,object_totals'
 # ��������� ��������� ���������� ����� ����������
 foreach($ParName in 'message_stats.ack_details.rate', 'message_stats.ack',
  'message_stats.deliver_get_details.rate', 'message_stats.deliver_get',
  'message_stats.get_details.rate', 'message_stats.get',
  'message_stats.publish_details.rate', 'message_stats.publish',
  'object_totals.channels', 'object_totals.connections',
  'object_totals.consumers', 'object_totals.exchanges', 'object_totals.queues',
  'queue_totals.messages', 'queue_totals.messages_ready',
  'queue_totals.messages_unacknowledged'){
  # �������� ��������� - ���������� �������� ����������
  $ParValue = $Overview
  # ��������� �������� ���������
  foreach($i in $ParName.Split('.')){ $ParValue = $ParValue.$i }
  # �������� �� ��������� - ������������� ������� ���������
  if($ParValue -eq $null){ $ParValue = 0 }
  # ����� ����� � �������� ��������� � ������� zabbix_sender
  $OutStr += '- rabbitmq.' + $ParName + ' ' + $ParValue + "`n"
 }

 # ��������� ������ ��������
 foreach($Queue in $QueuesStr.name.Split('`n')){
  # ������ ������� ���������� �������
  $QueueQueryStr = 'queues/%2f/' + $Queue + '?columns=message_stats,memory,messages,messages_ready,messages_unacknowledged,consumers'
   # ���������� �������
  $QueueStat = RabbitMQAPI "$QueueQueryStr"
  # ��������� ��������� ���������� ���������� �������
  foreach($ParName in 'consumers', 'memory', 'messages', 'messages_unacknowledged', 'messages_ready'){
   # �������� ���������
   $ParValue = $QueueStat.$ParName
   # �������� �� ��������� - ������������� ������� ���������
   if($ParValue -eq $null){ $ParValue = 0 }
   # ����� ����� � �������� ��������� � ������� zabbix_sender
   $OutStr += '- rabbitmq.' + $ParName + '[' + $Queue + '] ' + $ParValue + "`n"
  }
 }

 # �������� ���������� �������� ������.
 # �������� ������ ������ ������� Zabbix. ��������� zabbix_sender:
 #  --config      ���� ������������ ������;
 #  --host        ��� ���� ���� �� ������� Zabbix;
 #  --input-file  ���� ������('-' - ����������� ����)
 $OutStr.TrimEnd("`n") | c:\Scripts\zabbix_sender.exe --config "c:\Scripts\zabbix_agentd_win.conf" --host "DNS.���.�������" --input-file - 2>&1 | Out-Null

 # ������� ������� ������� - '��������'
 Write-Host 1
}
