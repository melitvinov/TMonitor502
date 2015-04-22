unit Calc502;

interface

uses SysUtils,FController,FConstType,MessageU,Stg;

{***********************************************************
--------------------�������� ����� �������-----------------
************************************************************}
type T1Timer=record
    Res1,StartTime,EndTime:SmallInt;//int16;
    Stg:array[0..33] of Char;
    T,TV,RH,DDWP,CO2,Res2,Res3:SmallInt;//int16;
    end;

    Tp1Timer=^T1Timer;
    TTimers=array [1..20] of T1Timer;
    TpTimers=^TTimers;

type TTimer502=Class(TBlock)
private
      pTimers:TpTimers;
      ATimer,BTimer:Byte;
public
     procedure Init;override;
     function LoadXYvirt(vInBlock:Byte;ValX,ValY:Integer;
       var Txt:String):Double;override;
     function SetAny(Col,Row,x,y:integer;var Any:TAny):Integer;override;
     function GetTimer(tTime:TDateTime; var ResTimer:T1Timer):Boolean;
end;

implementation

uses ClimCalc,SetGrid,TeEngine, Series, StdCtrls, TeeProcs,GanttCh,Chart,DateUtils,
  Math;

{***********************************************************
--------------------������������� ����� �������-----------
************************************************************}

// ���� min=-1 ��� �������� ��� ����� ������������ (��� ���� �� ���� �� ) ������ �������� ��� ����� ���� (�� ���������)
const YTimerSum502=9;  XTimerSum502=20;
      yStartTime=3; yT=5; yRH=6; yDDWP=7;

var  NameTimer502:array [1..YTimerSum502] of TNameConst=(
 (Name:'����� ������ �������� ��������� (���� 0 - ����� �� �������)';Frm:SShSSm;Ed:'���:���';TipSens:TipCalc;Min:0;Max:0;Def:0;
    Index:2;GridColor:$ffef00;AccessR:RW_GUEST;AccessW:RW_GUEST),
 (Name:'��� ������';Frm:ComboSS;Ed:'';TipSens:TipCalc;Min:657;Max:661;Def:0;
    Index:4;GridColor:$ffef00;AccessR:RW_GUEST;AccessW:RW_GUEST),
 (Name:'����� ������';Frm:SShSSm;Ed:'���:���';TipSens:TipCalc;Min:0;Max:0;Def:0;
    Index:0;GridColor:$ffef00;AccessR:RW_GUEST;AccessW:RW_GUEST),

 (Name:'��������� ����������';Frm:SFStr;Ed:'';TipSens:TipText;Min:-1;Max:0;Def:HIDE_MIN_MAX;
    Index:6;GridColor:$ff0faf;Mech:0;AccessR:RW_GUEST;AccessW:RW_GUEST),


// (Name:'��� ������';Frm:SS;Ed:'';TipSens:TipCalc;Min:0;Max:0;Def:0;
//    Index:3;GridColor:$ffdf00;AccessR:RW_GUEST;AccessW:RW_GUEST),
 (Name:'������� ����������� ������� (���� 0-����� �� �������)';Frm:SSpS0;Ed:'�C';TipSens:TipCalc;Min:0;Max:30;Def:HIDE_MIN_MAX;
    Index:40;GridColor:$ff0faf;Mech:0;AccessR:RW_GUEST;AccessW:RW_GUEST;Kind:kdProgTask),
 (Name:'������� ��������� ������� (���� 0-�� �� ���������)';Frm:SSpS0;Ed:'%';TipSens:TipCalc;Min:0;Max:95;Def:HIDE_MIN_MAX;
    Index:44;GridColor:$ff0faf;Mech:0;AccessR:RW_GUEST;AccessW:RW_GUEST;Kind:kdProgTask),
 (Name:'������� ������� �������� ���� ';Frm:SSpS0;Ed:'�/�3';TipSens:DDWP;Min:0;Max:0;Def:0;
    Index:46;GridColor:$ff0faf;Mech:0;AccessR:RW_GUEST;AccessW:RW_GUEST),
 (Name:'����������� ����������';Frm:SSpS0;Ed:'�C';TipSens:TipCalc;Min:0;Max:40;Def:HIDE_MIN_MAX;
    Index:42;GridColor:$ff0faf;Mech:0;AccessR:RW_GUEST;AccessW:RW_GUEST),
 (Name:'������� ������������ CO2 (���� 0 - �� ���������)';Frm:SSSS;Ed:'ppm';TipSens:TipCalc;Min:0;Max:3000;Def:HIDE_MIN_MAX;
    Index:48;GridColor:$ff0faf;Mech:0;AccessR:RW_GUEST;AccessW:RW_GUEST;Kind:kdProgTask)
);
var XNamesTimer502:array [1..1] of TXNames=(
    (Name:'�������';Frm:None;Ed:'';Index:SizeOf(T1Timer);Cfg:0;Kind:0)
     );

var taskArray:array[1..XTimerSum502,1..YTimerSum502] of Double;

procedure TTimer502.Init;//override;
var HotY,TimY:integer;
begin
     CountX:=XTimerSum502;
     CountY:=YTimerSum502;
     SizeCol:=SizeOf(T1Timer);
     FullSize:=CountX*SizeCol;
     SendByte:=FullSize;
     Pref:=ProgMess[224];      //'�������';
     NameBlock:=ProgMess[225];  //  '������� ������������';
     FixRow:=1;
     ConstNames:=Addr(NameTimer502);
     XNames:=Addr(XNamesTimer502[1]);
     XNamesCount:=1;
//     SavingConstNames:=True;
     HotY:=1; TimY:=1;
     while HotY < ParentCtr.Block[0].CountY do
            begin
            if (ParentCtr.Block[0].ConstNames[HotY].Kind and kdProgTask)>0
              then
               while TimY<CountY do
                  begin
                  if (ConstNames[TimY].Kind and kdProgTask)>0
                   then begin ConstNames[TimY].Tag:=HotY; inc(TimY); break; end;
                   inc(TimY);
                   end;
            inc(HotY);
            end;
     Translator:=CountY;
end;

{***********************************************************
--------------------�������� �������� ����� ������-------------
************************************************************}
function TTimer502.LoadXYvirt(vInBlock:Byte;ValX,ValY:Integer;
     var Txt:String):Double;
var  st:string;
     RH,T:integer;
     StTime:double;
     Mode:Byte;
begin
if (ValY>0) and (ValX>0) then
  begin
  if ValY=yStartTime then
      begin
      StTime:=LoadXY(cOutBlock,ValX,ValY-2,Txt)*60;
      Mode:=round(LoadXY(cOutBlock,ValX,ValY-1,Txt));
      case Mode of
        1: StTime:=MinuteOfTheDay(GlobSunRaise)-StTime;
        2: StTime:=MinuteOfTheDay(GlobSunRaise)+StTime;
        3: StTime:=MinuteOfTheDay(GlobSunSet)-StTime;
        4: StTime:=MinuteOfTheDay(GlobSunSet)+StTime;
        end;
      Txt:=FormatDateTime('hh:mm',StTime*cMin);
      Result:=inherited LoadXYvirt(cOutTxtBlock,ValX,ValY,Txt);
      Exit;
      end;
  if ValY=yDDWP then
      begin
      if (vInBlock=cInBlock) then
          begin
          Result:=inherited LoadXYvirt(cInBlock,ValX,ValY,Txt);
          T:=round(LoadXY(cOutBlock,ValX,yT,st)*100);
          st:=FloatToStr(GetRH_DDWP(T,round(Result*100)));
          inherited LoadXYvirt(cInBlock,ValX,yRH,st);
          end
      else
          begin
          RH:=round(LoadXYvirt(cOutBlock,ValX,yRH,st)*100);
          T:=round(LoadXY(cOutBlock,ValX,yT,st)*100);
          Txt:=FloatToStr(GetDDWP(T,RH)/100);
          Result:=inherited LoadXYvirt(cInBlock,ValX,ValY,Txt);
          end;
      Exit;
      end;
    end;
  Result:=inherited LoadXYvirt(vInBlock,ValX,ValY,Txt);
{      Txt:=GetRH_DDWP(pTimers^[ValX].T,tIn);
      end;
  pTimers:=Adr;
  if (ValX>0) and (ValY>0) then
      begin
      if (pTimers^[ValX].StartTime=0) or (pTimers^[ValX].T=0) or (pTimers^[ValX].Stg=#0) then
        GridCellColor:=$e0e0e0;//clSilver;
      if (ConstNames[ValY].TipSens = DDWP) then
        begin
          tIn:=GetDDWP(pTimers^[ValX].T,pTimers^[ValX].RH);//*100);
        Result:=Convers(ConstNames[ValY].Name,
         Addr(tIn),SSpS0,vInBlock,ValX,ValY,Txt,ConstNames[ValY].Ed);
        if (vInBlock=cInBlock) then
             begin
             NewRH:=GetRH_DDWP(pTimers^[ValX].T,tIn);
             if (NewRH > 0) then pTimers^[ValX].RH:=NewRH;
             end;
        Exit;
        end;
      end;
    Result:=inherited LoadXYvirt(vInBlock,ValX,ValY,Txt); }
end;

{function startTypeGetStartTime(time:Double; startType:integer):Double;
var
  sunRise, sunSet,tempTime:Double;
  pTimer:PByteArray;
  pHot:PByteArray;
begin
  sunRise := MinuteOfTheDay(GlobSunRaise);
  sunSet := MinuteOfTheDay(GlobSunSet);
  case startType of
    0:  //START_OFF
      begin
        Result := time;
      end;
    1:  //START_BEFORE_SUNSET
      begin
        tempTime := (sunSet) - time;
        if tempTime <= cMin then
          Result := cMin
        else
          Result := tempTime;
      end;
    2:  //START_AFTER_SUNSET
      begin
        tempTime := sunSet + time;
        if tempTime > (24*60) then
          Result := tempTime - (24*60)
        else
          Result := tempTime;
      end;
    3:  //START_BEFORE_SUNRISE
      begin
        tempTime := (sunRise) - time;
        if tempTime <= cMin then
          Result := cMin
        else
          Result := tempTime;
      end;
    4:  //START_AFTER_SUNRISE
      begin
        tempTime := sunRise + time;
        if tempTime > (24*60) then
          Result := tempTime - (24*60)
        else
          Result := tempTime;
      end;
  end;
end;}

function TTimer502.GetTimer(tTime:TDateTime; var ResTimer:T1Timer):Boolean;
var nTim:integer; tMin,tEnd:integer;
    d:double;
    nTmin, nTmax:integer;
    st:string;
    startTime:integer;
    tempMin,tempMax:double;
begin
  pTimers:=Adr;
  ATimer:=0; BTimer:=0;
  tMin:=MinuteOfTheDay(tTime);
  Result:=False;
  tempMin := 1440;
  tempMax := 1440;
  for nTim:=1 to CountX do
    with pTimers^[nTim] do
      begin
        if (pTimers^[nTim].StartTime=0) or (pTimers^[nTim].T=0) then continue;
        if (tMin > pTimers^[nTim].StartTime) and (pTimers^[nTim].StartTime <= tempMin) then
          begin
            tempMin := pTimers^[nTim].StartTime;
            nTmin:=nTim;
          end;
          if (tMin < pTimers^[nTim].StartTime) and (pTimers^[nTim].StartTime <= tempMax) then
            begin
              tempMax := pTimers^[nTim].StartTime;
              nTmax:=nTim;
            end;
      end;
  ATimer:=nTmin;
  BTimer:=nTmax;
  if ATimer=0 then ATimer:=BTimer;
  if BTimer=0 then BTimer:=ATimer;
// ����������� ����� !!!!!!!!!!!!!!!!!!!!!!!!!!!!





  if ATimer>0 then
    begin
      d:=pTimers^[BTimer].StartTime-pTimers^[ATimer].EndTime;
      if d=0 then d:=0 else d:=(tMin-pTimers^[ATimer].EndTime)/d;
//todo      with ParentCtr as TFClimat502 do CalcStrategyBlock.GetStgFromName(pTimers^[ATimer].Stg);
      end;
//  with ParentCtr as TFClimat502 do
   for nTim:=1 to CountY do //TaskCount do
      begin
      if ConstNames[nTim].Tag<=0 then continue;
      if ATimer=0 then st:='0'
      else
        st:=FloatToStr((1-d)*LoadXY(cOutBlock,ATimer,nTim,st)+d*LoadXY(cOutBlock,BTimer,nTim,st));
      ParentCtr.Block[0].LoadXY(cInBlock,1,ConstNames[nTim].Tag,st);
      end;
end;

const tmSt=1;tmEnd=2;valDt=3;LstTm=1;LstDt=2;Sum=3;Lg=4;
//type TStatZ=array [1..DZ_NumTimer,1..4,1..Lg] of double;
type tsk1=record tmSt,tmEnd,valDt:Double; end;
type TStatZ=array [0..XTimerSum502,1..4] of tsk1;

procedure InitZ(var StatZ:TStatZ);
var i:integer;
begin
  for i:=1 to 4 do StatZ[0,i].tmSt:=0;
end;

function InsZ(var StatZ:TStatZ;vZ:integer;tsk:tsk1):Integer;
var i,cnt,fnd:integer;
begin
  cnt:=round(StatZ[0,vZ].tmSt);
  StatZ[0,vZ].tmSt:=cnt+1;
  fnd:=0;
  for i:=1 to cnt do
      if tsk.tmSt < StatZ[i,vZ].tmSt then begin fnd:=i; break; end;
  if fnd=0 then
      begin
      StatZ[cnt+1,vZ]:=tsk;
      Exit;
      end;
  for i:=cnt downto fnd do StatZ[i+1,vZ]:=StatZ[i,vZ];
  StatZ[fnd,vZ]:=tsk;
end;

function GetZ(var StatZ:TStatZ;vZ:integer;Gradient:integer):string;
var i,cnt:integer;
  sm,lg,tmLast,valLast,dd,ddd:double;
begin
  cnt:=round(StatZ[0,vZ].tmSt);
  if cnt<1 then begin Result:='��� ���'; Exit; end;
  sm:=0; lg:=0;
  for i:=1 to cnt do
      begin
      if sm<>0  then
          begin
          dd:=StatZ[i,vZ].tmSt-tmLast;
          if dd <= 0 then begin Result:='�������'; ActionMes:=ProgMess[209]; Exit; end;
          ddd:=(StatZ[i,vZ].valDt-valLast)*cMin*60/dd;
          if (ddd > Gradient) or (ddd < -Gradient)  then
             begin ActionMes:=Format(ProgMess[210],[Gradient]); Result:='>'+IntToStr(Gradient)+'� ���'; Exit; end;
          sm:=sm+(StatZ[i,vZ].valDt+valLast)*dd/2;
          lg:=lg+dd;
          end;
      dd:=StatZ[i,vZ].tmEnd-StatZ[i,vZ].tmSt;
      valLast:=StatZ[i,vZ].valDt;
      tmLast:=StatZ[i,vZ].tmEnd;
      sm:=sm+valLast*dd;
      lg:=lg+dd;
      end;
  dd:=StatZ[1,vZ].tmSt-tmLast;
  if dd<0 then dd:=dd+24*60*cMin;
  sm:=sm+(StatZ[1,vZ].valDt+valLast)*dd/2;
  lg:=lg+dd;
  if lg<>0 then Result:=Format('%f C',[sm/lg]) else Result:='err';
end;

function TTimer502.SetAny(Col,Row,x,y:integer;var Any:TAny):Integer;
var ChartBl:TChart;
    iX:integer;
    dbStart,dbPrevStart,dbNextStart,dbEnd:Double;
    dbTempSet:Double;
    dbStrategSet:string;
    currentTime:Double;
    dbTypeStart:Integer;
    st:string;
    i,j:integer;
    temp,ttemp:Double;
begin
  // show in the ChartBl from array
  ChartBl:=Any.Ptr;
  with ChartBl do
  begin
    Series[0].Clear;
    for iX:=1 to CountX-1 do
      begin
      dbStart := LoadXYvirt(cOutBlock, iX, 3,st);
      dbTypeStart := Round(LoadXYvirt(cOutBlock, iX, 2,st));
      dbEnd := LoadXYvirt(cOutBlock, iX, 3,st);
      dbTempSet := LoadXYvirt(cOutBlock, iX, 5,st);
      LoadXYvirt(cOutBlock, iX, 5,dbStrategSet);
      if (dbStart=0) or (dbTempSet=0) or (dbStrategSet='') then continue;
      if dbEnd=0 then dbEnd:=24*60*cMin;
        with (Series[0] as TGanttSeries) do
          begin
            if LoadXYvirt(cOutBlock, iX, 3,st) > 0 then
            begin
              temp := 24;
              for i:=1 to CountX do
              if LoadXYvirt(cOutBlock, i, 3,st) > 0 then
                if (LoadXYvirt(cOutBlock, i, 3,st) > dbEnd) and (LoadXYvirt(cOutBlock, i, 3,st) <= temp) then
                  temp := LoadXYvirt(cOutBlock, i, 3,st);
              AddGantt(dbStart*60*cMin, temp*60*cMin,iX*3,Format(ProgMess[235],[iX]));
            end;
          end;
        if Row > 4 then
        with (Series[ChartBl.Tag]as TFastLineSeries) do
        begin
          if LoadXYvirt(cOutBlock, iX, 3,st) > 0 then
            AddXY(dbStart*60*cMin,LoadXYvirt(cOutBlock, iX, Row,st),'',clTeeColor);
          temp := 24;
          for i:=1 to CountX do
            if (LoadXYvirt(cOutBlock, i, 3,st) < temp) and (LoadXYvirt(cOutBlock, i, 3,st) > 0) then
            begin
              temp := LoadXYvirt(cOutBlock, i, 3,st);  j:=i;
            end;
          AddXY(24*60*cMin,LoadXYvirt(cOutBlock, j, Row,st),'',clTeeColor);
        end;
    end;
  end;
end;

end.