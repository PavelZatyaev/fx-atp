//считаем все раздвижки, затраты и ищем треугольник для входа и сразу же открываемся

#include "head.mqh"

void fnCalcDelta(stThree &MxSmb[],double prft, string cmnt, ulong magic,double lot, ushort lcMaxThree, ushort &lcOpenThree)
   {     
      double   temp=0;
      string   cmnt_pos="";
      
      for(int i=ArraySize(MxSmb)-1;i>=0;i--)
      {//for i
         // если треугольнки в работе то мы его пропускаем
         if(MxSmb[i].status!=0) continue; 
         
         // снова делаем проверку на доступность всех трёх пар, так как если хоть одна из них недоступна
         // то считать весь треугоьник нет смысла
         if (!fnSmbCheck(MxSmb[i].smb1.name)) continue;  
         if (!fnSmbCheck(MxSmb[i].smb2.name)) continue;  //вдруг по какой то паре закрыли торги
         if (!fnSmbCheck(MxSmb[i].smb3.name)) continue;  
         
         // проверим доступность треугольника, таймаут на треугольнике выставляется в случае необработки ордера(ов)
         // сбой может иметь технический характер и превести к большим потерям
         if(MxSmb[i].timeout > 0) continue;
         
         // количество открытых треугольников считаем вначале каждого тика
         // но ведь мы можем и внутри тика открыть их, поэтому постоянно отслеживаем их количество
         if (lcMaxThree>0) {if (lcMaxThree>lcOpenThree); else continue;}//можно открывать ещё или нет
         
         // далее получем все необходимые данные для расчётов
         
         // получили стоимость тика по каждой паре
         if(!SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_TRADE_TICK_VALUE,MxSmb[i].smb1.tv)) continue;
         if(!SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_TRADE_TICK_VALUE,MxSmb[i].smb2.tv)) continue;
         if(!SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_TRADE_TICK_VALUE,MxSmb[i].smb3.tv)) continue;
         
         // получили текущие цены
         if(!SymbolInfoTick(MxSmb[i].smb1.name,MxSmb[i].smb1.tick)) continue;
         if(!SymbolInfoTick(MxSmb[i].smb2.name,MxSmb[i].smb2.tick)) continue;
         if(!SymbolInfoTick(MxSmb[i].smb3.name,MxSmb[i].smb3.tick)) continue;
         
         // как и говорил ранее, почему то при успешном поулчении цен иногда бывает что аск или бид = 0
         // приходиться тратить время на проверку цен
         if(MxSmb[i].smb1.tick.ask<=0 || MxSmb[i].smb1.tick.bid<=0 || MxSmb[i].smb2.tick.ask<=0 || MxSmb[i].smb2.tick.bid<=0 || MxSmb[i].smb3.tick.ask<=0 || MxSmb[i].smb3.tick.bid<=0) continue;
         
         // считаем объём для третьей пары. Делаем это здесь потому что у первых двух пар объём известен, он одинаковый и фиксированный
         // объём третьей пары всегд меняется. Также не забываем что считаем объём только если в стартовых переменных значение лота не равно 0
         // в этом случае используется везди минимальный, одинаковый объём - сложно сказать зачем этот режим нужен, но возможности лучше когда есть
         // чем когда их нет
         // логика расчёта объёма простая. вспоминаем наш вариант треугольника: EURUSD=EURGBP*GBPUSD. количество купленных или проданных фунтов
         // напрямую зависит от котировки EURGBP, а в третьей паре это третья валюта стоит на первом месте, т.е. мыизбавляем себя от части расчётов
         // беря в качестве объёмо просто цену второй пары.и всё. это ещё один плюс почему мы выбрали именно этот вариант построения треугольника
         // также важно направление, покупка или продажа, но учитвая что спред влияет только на 4 знак, а округление лотности идёт вообще только до
         // второго знкак после запятой, то направлением можно смело пренебречь. Я взял среднее между аском и бидом.
         // и конечно не забываем о поправке на входной торговый объём.
         
         if (lot>0)
         MxSmb[i].smb3.lot=NormalizeDouble((MxSmb[i].smb2.tick.ask+MxSmb[i].smb2.tick.bid)/2*MxSmb[i].smb1.lot,MxSmb[i].smb3.digits_lot);
         
         // если расчитанный объём выходит за допустимые границы, то сообщем об этом пользователю
         // самы ничего не делаем. Данный треугольник помечаем как нерабочий
         if (MxSmb[i].smb3.lot<MxSmb[i].smb3.lot_min || MxSmb[i].smb3.lot>MxSmb[i].smb3.lot_max)
         {
            Alert("The calculated lot for ",MxSmb[i].smb3.name," is out of range. Min/Max/Calc: ",
            DoubleToString(MxSmb[i].smb3.lot_min,MxSmb[i].smb3.digits_lot),"/",
            DoubleToString(MxSmb[i].smb3.lot_max,MxSmb[i].smb3.digits_lot),"/",
            DoubleToString(MxSmb[i].smb3.lot,MxSmb[i].smb3.digits_lot)); 
            Alert("Triangle: "+MxSmb[i].name()+ " - DISABLED");
            MxSmb[i].smb1.name="";   
            continue;  
         }
         
         // считаем наши затраты т.е. спред+комиссии. pr = спред в целых пунктах
         // именно спред мешает нам зарабатывать данной стратегией, поэтому его необходимо учитывать обязательно
         // можно использовать не разницу цен, умноженную на обратный поинт, а взять сразу спред в пунктах
         // SymbolInfoInteger(Symbol(),SYMBOL_SPREAD) - сейчас уже сложно сказать почему я не выбрал этот вариант
         // может быть из за того что цены у меня уже получены и чтобы ещ раз не обращаться к окружению
         // может быть ранее проводил тесты как быстрее. не помню, робот написан очень давно.
         
         MxSmb[i].smb1.sppoint=NormalizeDouble(MxSmb[i].smb1.tick.ask-MxSmb[i].smb1.tick.bid,MxSmb[i].smb1.digits)*MxSmb[i].smb1.Rpoint;
         MxSmb[i].smb2.sppoint=NormalizeDouble(MxSmb[i].smb2.tick.ask-MxSmb[i].smb2.tick.bid,MxSmb[i].smb2.digits)*MxSmb[i].smb2.Rpoint;
         MxSmb[i].smb3.sppoint=NormalizeDouble(MxSmb[i].smb3.tick.ask-MxSmb[i].smb3.tick.bid,MxSmb[i].smb3.digits)*MxSmb[i].smb3.Rpoint;
         
         // Звучит дико, но да, проверяем спред на отрицательное значение - в тестере такое сплошь и рядом. В реалтайме с таким не сталкивался
         if (MxSmb[i].smb1.sppoint<=0 || MxSmb[i].smb2.sppoint<=0 || MxSmb[i].smb3.sppoint<=0) continue;
         
         // есть спред в пунтках, теперь считаем его в деньгах, а точнее в валюте депозита
         // в валюте стоимость 1 тика всегда равна параметру SYMBOL_TRADE_TICK_VALUE
         // также не забываем о торговых объёмах
         MxSmb[i].smb1.spcost=MxSmb[i].smb1.sppoint*MxSmb[i].smb1.tv*MxSmb[i].smb1.lot;
         MxSmb[i].smb2.spcost=MxSmb[i].smb2.sppoint*MxSmb[i].smb2.tv*MxSmb[i].smb2.lot;
         MxSmb[i].smb3.spcost=MxSmb[i].smb3.sppoint*MxSmb[i].smb3.tv*MxSmb[i].smb3.lot;
         
         // итак вот наши затраты, на указанный торговый объём с добавленной комиссией, которую указывает пользователь
         MxSmb[i].spread=MxSmb[i].smb1.spcost+MxSmb[i].smb2.spcost+MxSmb[i].smb3.spcost+prft;
         
         // как и говорил ранее, во вступлении, можно отслеживать ситуацию когда аск портфеля < бида портфеля, но это 
         // происходит настолько редко, что такие ситуации отдельно можно не рассматривать. Но к слову сказать
         // арбитраж, разнесённый во времени, данную ситуацию тоже обработает.
         // итак, я ранее утверждал что нахождении в позиции без рисков, вот почему:
         // к примеру мы купили eurusd, и здесь же его сразу продали, но через eurgbp и gbpusd
         // то есть мы увидели что ask eurusd< bid eurgbp * bid gbpusd - таких ситуаций полным полно, но для успешного входа этого мало
         // нам необходимо ещё посчитать затраты на спред и в итоге мы должны входить не просто когда аск < бид, а когда разница между
         // ними больше наших затрат на спред, и только в этом слуаем можно пробовать заработать.          
         
         // договоримся что покупка это значит купили  первый символ и продали два оставшихся
         // а продажа это продали первую пару и купили две остальных
         
         temp=MxSmb[i].smb1.tv*MxSmb[i].smb1.Rpoint*MxSmb[i].smb1.lot;
         
         // разберём подробнее формулу расчёта
         // 1. в скобках каждая цена коректируется на просказльывание естественно в худшую сторону: MxSmb[i].smb2.tick.bid-MxSmb[i].smb2.dev
         // 2. как показано в формуле выше bid eurgbp * bid gbpusd - цены второго и третьего символа перемножаем:
         //    (MxSmb[i].smb2.tick.bid-MxSmb[i].smb2.dev)*(MxSmb[i].smb3.tick.bid-MxSmb[i].smb3.dev)
         // 3. Далее считаем разницу между аском и бидом просто вычитаем из одного другое
         // 4. мы получили разницу в пунтках, которую теперь надо перевести в деньги т.е. сначала пункты переводим в целое, далее умножаем 
         // стоимость пункта и торговый объём. Для этих целей берём значения первой пары, так как слева и справа у нас одно и тоже
         // если же мы бы строили треугольник переместив все пары в одну сторону и проводя сравнение с 1, то в данной ситуации расчётов было бы больше
         // поэтому выбран именно такой вариант формаирования, а не "классический"
         MxSmb[i].PLBuy=((MxSmb[i].smb2.tick.bid-MxSmb[i].smb2.dev)*(MxSmb[i].smb3.tick.bid-MxSmb[i].smb3.dev)-(MxSmb[i].smb1.tick.ask+MxSmb[i].smb1.dev))*temp;
         MxSmb[i].PLSell=((MxSmb[i].smb1.tick.bid-MxSmb[i].smb1.dev)-(MxSmb[i].smb2.tick.ask+MxSmb[i].smb2.dev)*(MxSmb[i].smb3.tick.ask+MxSmb[i].smb3.dev))*temp;
         
         // Мы получили деньги кторые можем заработать или потерять если купим или продадим треугольник
         // осталось сравнить с затратами ,если получаем больше чем тратим значит можно входить
         // плюс данного подхода - мы сразу знаем сколько ориентировочно мы можем заработать
         // нормализуем всё до 2 знака ,т.к. это уже деньги
         MxSmb[i].PLBuy=   NormalizeDouble(MxSmb[i].PLBuy,2);
         MxSmb[i].PLSell=  NormalizeDouble(MxSmb[i].PLSell,2);
         MxSmb[i].spread=  NormalizeDouble(MxSmb[i].spread,2);                  
         
         // если есть потенциальная прибыли то надо провести ещё проверки на достаточность средств для открытия         
         if (MxSmb[i].PLBuy>SPREAD_CF*MxSmb[i].spread || MxSmb[i].PLSell>SPREAD_CF*MxSmb[i].spread) //pz добавим 2%... 
         {
            // я не стал заморачиваться с направлением сделки, просто посчитал всю на маржу для покупки, она всё равно выше чем для продажи
            // также стоит обратить внимание на повышаюший коэффициент
            // нельзя открывать треугольник когда маржи хватает ели ели. Взят повышающий коэффициент, по умолчанию = 20%
            // правда эта проверка как ни странно иногда не срабатывает, до сих пор не понял почему
            if(OrderCalcMargin(ORDER_TYPE_BUY,MxSmb[i].smb1.name,MxSmb[i].smb1.lot,MxSmb[i].smb1.tick.ask,MxSmb[i].smb1.mrg))
            if(OrderCalcMargin(ORDER_TYPE_BUY,MxSmb[i].smb2.name,MxSmb[i].smb2.lot,MxSmb[i].smb2.tick.ask,MxSmb[i].smb2.mrg))
            if(OrderCalcMargin(ORDER_TYPE_BUY,MxSmb[i].smb3.name,MxSmb[i].smb3.lot,MxSmb[i].smb3.tick.ask,MxSmb[i].smb3.mrg))
            if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)>((MxSmb[i].smb1.mrg+MxSmb[i].smb2.mrg+MxSmb[i].smb3.mrg)*CF))  //проверили сводобную маржу
            {
            
               //pz
               if(glTimeout > 0) {
                  Print("Timeout(pz)");
                  break;
               }

               // если мы здесь, значит почти готовы к открытию, осталось найти свободный магик из нашего диапазон
               // начальный магик указан во входных параметрах, в переменной inMagic, по умолчанию равен 300
               // диапазон магиков указан в дефайне MAGIC ,по умолчанию стоит 200 это с головой хватит на все треугольники
               MxSmb[i].magic=fnMagicGet(MxSmb,magic);   
               if (MxSmb[i].magic<=0)
               { // если вернули 0 значит все магики заняты, принтуем и выходим.
                  Print("Free magic ended\nNew triangles will not open");
                  break;
               }  
               
               // устанавливаем найденный магик роботу
               ctrade.SetExpertMagicNumber(MxSmb[i].magic); 
               
               // создадим комментарий для треугольника
               cmnt_pos=cmnt+(string)MxSmb[i].magic+" Open";               
               
               // открываемся, попутно запомнив время отправки треугольника на открытие
               // это нужно чтобы не висеть в ожидании вечно
               // по умолчанию, в дефайне MAXTIMEWAIT установлено время ожидания до полного открытия 3 секунды
               // если за это время мы не октрылись то отправляем треугольник, точнее то что успело открыться на закрытие
               
               MxSmb[i].timeopen=TimeCurrent();
               
               
               if (MxSmb[i].spread > 0 && MxSmb[i].spread < 1000) { //pz 
                   if (MxSmb[i].PLBuy>MxSmb[i].spread)    { //pz
                     if (MxSmb[i].PLBuy < 1000000) {
                        fnOpen(MxSmb,i,cmnt_pos,true,lcOpenThree);
                     }
                     else {
                        Print("Error giant PLBuy = ", MxSmb[i].PLBuy);
                     }   
                   }
                   
                   if (MxSmb[i].PLSell>MxSmb[i].spread)   {
                     if (MxSmb[i].PLSell < 1000000) {
                        fnOpen(MxSmb,i,cmnt_pos,false,lcOpenThree);               
                     }    
                     else {
                        Print("Error giant PLSell = ", MxSmb[i].PLSell);
                     }   
                   }
               }
               else {
                Print("Error giant spread = ", MxSmb[i].spread);
               }
               
               // принтанём что открываем треугольник
               if (MxSmb[i].status==1) {
                Print("Open triangle: " + MxSmb[i].name() + " magic: "+(string)MxSmb[i].magic,", spread: ", MxSmb[i].spread
                ,", MxSmb[i].PLBuy: ", MxSmb[i].PLBuy
                ,", MxSmb[i].PLSell: ", MxSmb[i].PLSell
                );
                glTimeout = 5; //pz установим таймаут на открытие следующего треугольника
                }
            }
         }         
      }//for i
   }
