//проверяем насколько успешно открылся треугольник.

#include "head.mqh"

void fnOpenCheck(stThree &MxSmb[], int accounttype, int fh)
   {
      uchar cnt=0;      //счётчик открытых позиций в треугольнике
      ulong   tkt=0;     //текущий тикет
      string smb="";    //текущий символ
      
      // проверяем наш массив треугольников
      for(int i=ArraySize(MxSmb)-1;i>=0;i--)
      {
         // рассматриваем только те треугольники которые отправлены на открытие, т.е. их статус = 1
         if(MxSmb[i].status!=1) continue;
                          
         if ((TimeCurrent()-MxSmb[i].timeopen)>MAXTIMEWAIT)
         {     
            // если превышено время отведённое на открытие, то помечаем треугольник как готовый к закрытию         
            MxSmb[i].status=3;
            Print("Not correct open: "+MxSmb[i].name());
            continue;
         }
         
         cnt=0;
         
         switch(accounttype)
         {
            case  ACCOUNT_MARGIN_MODE_RETAIL_HEDGING:
            
            // проверим все открытые позиции. Эту проверку делаем для каждого треугольника
            // идёт некоторый перерасход ресурсов ,но сйчас уже спешки нет, всё что могли открыть мы уже открыли
            for(int j=PositionsTotal()-1;j>=0;j--)
                if (PositionSelectByTicket(PositionGetTicket(j)))
                    if (PositionGetInteger(POSITION_MAGIC)==MxSmb[i].magic)
                    {
                       // получаем символ и тикет рассматриваемой позиции
                       tkt=PositionGetInteger(POSITION_TICKET);
                       smb=PositionGetString(POSITION_SYMBOL);
                       
                       // проверяем есть ли текущая позиция среди нужных нам в рассматриваемом треугольнике
                       // если есть то увеличиваем счётчик, запоминаем тикет и цену открытия и сбрасываем таймаут //pz
                       if (smb==MxSmb[i].smb1.name){ cnt++;   MxSmb[i].smb1.tkt=tkt;  MxSmb[i].smb1.price=PositionGetDouble(POSITION_PRICE_OPEN);} else
                       if (smb==MxSmb[i].smb2.name){ cnt++;   MxSmb[i].smb2.tkt=tkt;  MxSmb[i].smb2.price=PositionGetDouble(POSITION_PRICE_OPEN);} else
                       if (smb==MxSmb[i].smb3.name){ cnt++;   MxSmb[i].smb3.tkt=tkt;  MxSmb[i].smb3.price=PositionGetDouble(POSITION_PRICE_OPEN);} 
                       
                       // если нашли три необходимых позиции, значит наш треугольник успешно открыт. меняем его статус на 2 (открытый)
                       // и запишем данные об открытие в лог файл
                       if (cnt==3)
                       {
                          MxSmb[i].status=2;
                          MxSmb[i].timeout = 0;
                          MxSmb[i].timeout_count = 0;
                          fnControlFile(MxSmb,i,fh);
                          break;   
                       }
                    }
            break;
            default:
            break;
         }
      }
   }