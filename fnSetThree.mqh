//составляем рабочие треугольники

#include "head.mqh"

void fnSetThree(stThree &MxSmb[],enMode mode)
   {
      // сбрасываем наш массив треугольников
      ArrayFree(MxSmb);
      
      // смотрим где мы, в тестере или нет
      if((bool)MQLInfoInteger(MQL_TESTER))
      {
         // если да, то ищем файл символов и запускаем загрузку треугольников из файла
         if(FileIsExist(FILENAME)) fnGetThreeFromFile(MxSmb);
         
         // если файл не найден, то перебираем все доступные символы и ищем среди них дефольтный треугольник EURUSD+GBPUSD+EURGBP
         else{               
            char cnt=0;         
            for(int i=SymbolsTotal(false)-1;i>=0;i--)
            {
               string smb=SymbolName(i,false);
               if ((SymbolInfoString(smb,SYMBOL_CURRENCY_BASE)=="EUR" && SymbolInfoString(smb,SYMBOL_CURRENCY_PROFIT)=="GBP") ||
               (SymbolInfoString(smb,SYMBOL_CURRENCY_BASE)=="EUR" && SymbolInfoString(smb,SYMBOL_CURRENCY_PROFIT)=="USD") ||
               (SymbolInfoString(smb,SYMBOL_CURRENCY_BASE)=="GBP" && SymbolInfoString(smb,SYMBOL_CURRENCY_PROFIT)=="USD"))
               {
                  if (SymbolSelect(smb,true)) cnt++;
               }               
               else SymbolSelect(smb,false);
               if (cnt>=3) break;
            }  
            
            // после того как загрузили дефолтный треугольник в обзор рынка, запустим составление треугольника         
            fnGetThreeFromMarketWatch(MxSmb);
         }
         return;
      }
      
      // если мы не в тестере то смотрим какой режим работы выбрал пользователь
      // фзять символы из обзора рынка, или из файла
      if(mode==STANDART_MODE || mode==CREATE_FILE) fnGetThreeFromMarketWatch(MxSmb);
      if(mode==USE_FILE) fnGetThreeFromFile(MxSmb);     
   }
//+------------------------------------------------------------------+

//получили треугольники из файла
void fnGetThreeFromFile(stThree &MxSmb[])
   {
      // если файл с символами не найден то принтуем об этом и завершаем работу
      int fh=FILEOPENREAD(FILENAME);
      if(fh==INVALID_HANDLE)
      {
         Print("File with symbols not read!");
         ExpertRemove();
      }
      
      // переводим каретку в начало файла
      FileSeek(fh,0,SEEK_SET);
      
      // пропусткаем заголовок т.е. первую строку файла      
      while(!FileIsLineEnding(fh)) FileReadString(fh);
      
      
      while(!FileIsEnding(fh) && !IsStopped())
      {
         // получим три символа треугольника. Сделаем базовую проверку на доступность данных и всё.
         // так как файл с треугольниками робот умеет составлять автоматически и если пользователь вдруг
         // изменил его самостоятельно и некорретно то считаем что он это сделал осознанно
         string smb1=FileReadString(fh);
         string smb2=FileReadString(fh);
         string smb3=FileReadString(fh);
         
         // если данные по символам доступны, то промотав до конца строки, запишем их в наш массив треугольников
         if (!csmb.Name(smb1) || !csmb.Name(smb2) || !csmb.Name(smb3)) {while(!FileIsLineEnding(fh)) FileReadString(fh);continue;}
         
         int cnt=ArraySize(MxSmb);
         ArrayResize(MxSmb,cnt+1);
         MxSmb[cnt].smb1.name=smb1;
         MxSmb[cnt].smb2.name=smb2;
         MxSmb[cnt].smb3.name=smb3;
         while(!FileIsLineEnding(fh)) FileReadString(fh);
      }
   }

//получили треугольники из обзора рынка
void fnGetThreeFromMarketWatch(stThree &MxSmb[])
   {
      // получаем общее количество символов
      int total=SymbolsTotal(true);
      
      // переменные для сравнения размера контрактов    
      double cs1=0,cs2=0;              
      
      // в первом цикле берём первый символ из списка
      for(int i=0;i<total-2 && !IsStopped();i++)    
      {//1
         string sm1=SymbolName(i,true);
         
         // проверяем символ на различные ограничения
         if(!fnSmbCheck(sm1)) continue;      
              
         // получаем размер контракта и сразу его нормализуем, т.к. в будущем будуем это значение сравнивать
         if (!SymbolInfoDouble(sm1,SYMBOL_TRADE_CONTRACT_SIZE,cs1)) continue; 
         cs1=NormalizeDouble(cs1,0);
         
         // получаем базовую валюту и валюту прибыли т.к. сравнение проводим именно по ним, а не по наименованию пары
         // таким образом не будут иметь значения различные префиксы и суффиксы придумываемые брокером
         string sm1base=SymbolInfoString(sm1,SYMBOL_CURRENCY_BASE);     
         string sm1prft=SymbolInfoString(sm1,SYMBOL_CURRENCY_PROFIT);
         
         // во втором цикле берём следующий символ из списка
         for(int j=i+1;j<total-1 && !IsStopped();j++)
         {//2
            string sm2=SymbolName(j,true);
            if(!fnSmbCheck(sm2)) continue;
            if (!SymbolInfoDouble(sm2,SYMBOL_TRADE_CONTRACT_SIZE,cs2)) continue;
            cs2=NormalizeDouble(cs2,0);
            string sm2base=SymbolInfoString(sm2,SYMBOL_CURRENCY_BASE);
            string sm2prft=SymbolInfoString(sm2,SYMBOL_CURRENCY_PROFIT);
            
            // у первой и второй пары должно быть одно совпадение любой из валют
            // если его нет, значит треугольник из никак составит не сможем    
            // при этом проверку на полную идентичность проводить смысла нет, потому что если будут к примеру
            // eurusd и eurusd.xxx то треугольник из них всё равно не составится
            if(sm1base==sm2base || sm1base==sm2prft || sm1prft==sm2base || sm1prft==sm2prft); else continue;
                  
            // размеры контрактов должны быть одинаковыми            
            if (cs1!=cs2) continue;
            
            // в третьем цикле ищем последний символ для треугольника
            for(int k=j+1;k<total && !IsStopped();k++)
            {//3
               string sm3=SymbolName(k,true);
               if(!fnSmbCheck(sm3)) continue;
               if (!SymbolInfoDouble(sm3,SYMBOL_TRADE_CONTRACT_SIZE,cs1)) continue;
               cs1=NormalizeDouble(cs1,0);
               string sm3base=SymbolInfoString(sm3,SYMBOL_CURRENCY_BASE);
               string sm3prft=SymbolInfoString(sm3,SYMBOL_CURRENCY_PROFIT);
               
               // мы знаем что у первого и второго символа есть одна общая валюта. Чтобы составить треугольник надо найти такую
               // третью валютную пару, одна валюта которой совпадает с любой валютой из первой пары, а другая с
               // любой валютой из второй, если совпадения нет, значит эта пара не подходит
               if(sm3base==sm1base || sm3base==sm1prft || sm3base==sm2base || sm3base==sm2prft);else continue;
               if(sm3prft==sm1base || sm3prft==sm1prft || sm3prft==sm2base || sm3prft==sm2prft);else continue;
               if (cs1!=cs2) continue;
               
               // если дошли сюда значит все проверки пройдены и из трёх этих найденных пар можно составить треугольник
               // записываем его в наш массив
               int cnt=ArraySize(MxSmb);
               ArrayResize(MxSmb,cnt+1);
               MxSmb[cnt].smb1.name=sm1;
               MxSmb[cnt].smb2.name=sm2;
               MxSmb[cnt].smb3.name=sm3;
               break;
            }//3
         }//2
      }//1    
   }
