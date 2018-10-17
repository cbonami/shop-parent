create table sch_opdrachten.mlc_klanten_hulp_tabel as select ikl, gebruikersnaam from SCH_MLC.KLANT@mlc.vdab.be k where 1=2;
DECLARE
    aantalVerwerkt              NUMBER;
    totaalAantalVerwerkt        NUMBER;
    klantId                     NUMBER;
    opdracht_historiek_id       NUMBER;

    CURSOR smp_opdrachten IS    select /*+ RULE */
                                       o.*, smp.ikl as ikl, k.gebruikersnaam
                                from SCH_SMP.OPDRACHT o
                                     ,SCH_SMP.GEKOZENWERKPUNT g
                                     ,SCH_SMP.SLUITENDMAATPAK smp
                                     ,sch_opdrachten.mlc_klanten_hulp_tabel k
                                where k.ikl = smp.ikl
                                and   g.id=o.werkpunt_id
                                and   smp.id = g.smp_id
                                and   smp.status = 'A';
    CURSOR klantIdCursor(pIkl NUMBER)
    IS
        SELECT id
        FROM sch_opdrachten.klant
        WHERE ikl = pIkl;

BEGIN
    execute immediate 'alter table SCH_OPDRACHTEN.OPDRACHT disable constraint OPDRACHT_OPDRACHT_HIST_FK';
    execute immediate 'alter table SCH_OPDRACHTEN.OPDRACHT_HISTORIEK disable constraint   FK_OPDR_HIST_OPDRACHT_ID';
    execute immediate 'truncate table SCH_OPDRACHTEN.OPDRACHT_HISTORIEK';
    execute immediate 'truncate table SCH_OPDRACHTEN.OPDRACHT';
    execute immediate 'alter table SCH_OPDRACHTEN.OPDRACHT enable constraint OPDRACHT_OPDRACHT_HIST_FK';
    execute immediate 'alter table SCH_OPDRACHTEN.OPDRACHT_HISTORIEK enable constraint   FK_OPDR_HIST_OPDRACHT_ID';
    begin
    execute immediate 'drop table sch_opdrachten.mlc_klanten_hulp_tabel';
    exception
     when others then
       null;
    end;
    execute immediate 'create table sch_opdrachten.mlc_klanten_hulp_tabel as select ikl, gebruikersnaam from SCH_MLC.KLANT@mlc.vdab.be k where verwijderd=0';
    execute immediate 'create index sch_opdrachten.mlc_klanten_hulp_tabel_i1 on sch_opdrachten.mlc_klanten_hulp_tabel(ikl)';

    FOR opdracht
    IN smp_opdrachten
    LOOP

        DBMS_OUTPUT.put_line(opdracht.ikl);

        OPEN klantIdCursor(opdracht.ikl);
        FETCH klantIdCursor INTO klantId;
        if (klantIdCursor%NOTFOUND) THEN
            klantId:=null;
        END IF;
        CLOSE klantIdCursor;

        DBMS_OUTPUT.put_line('bestaande klant ?' || klantId);

        IF klantId is null then
            insert into SCH_OPDRACHTEN.KLANT(ID, IKL, BURGER_PROFIEL_CN, TS_CRE_UTC, TS_LW_UTC, USR_CRE, USR_LW, VERSIE)
            VALUES (SCH_OPDRACHTEN.KLANT_SEQ.nextval, opdracht.ikl,
                   opdracht.GEBRUIKERSNAAM,
                   CAST(sysdate - INTERVAL '2' HOUR as TIMESTAMP(4)), CAST(sysdate - INTERVAL '2' HOUR as TIMESTAMP(4)),
                   'Migratie', 'Migratie', 0) returning id into klantId;

            DBMS_OUTPUT.put_line('aangemaakte klant' || klantId);
        END IF;

        INSERT INTO SCH_OPDRACHTEN.OPDRACHT(ID, KLANT_ID, TYPE, AANMAAK_METHODE, DEADLINE, OPMERKING, OPDRACHT_CODE, TITEL,
                                            OPVOLGER, /*STATUS,*/ REFERENTIE_ID, REFERENTIE_CONTEXT, TS_CRE_UTC, USR_CRE, TS_LW_UTC, USR_LW, VERSIE)
        VALUES (
                   /*ID*/              opdracht.id,
                   /*KLANT_ID*/        klantId,
                   /*TYPE*/            opdracht.DTYPE,
                   /*AANMAAK_METHODE*/ 'MANUEEL',
                   /*DEADLINE*/        CAST(opdracht.DEADLINE as DATE),
                   /*OPMERKING*/       opdracht.OPMERKING,
                   /*OPDRACHT_CODE*/   opdracht.OPDRACHTCODE,
                   /*TITEL*/           opdracht.TITEL,
                   /*OPVOLGER*/        opdracht.OPVOLGER,
                   /*STATUS*/
                   /*REFERENTIE_ID*/   opdracht.WERKPUNT_ID,
                   /*REFERENTIE_CONTEXT*/  'SMP_WERKPUNT',
                   /*TS_CRE_UTC*/      CAST(opdracht.DTM_CRE - INTERVAL '2' HOUR as TIMESTAMP(4)),
                   /*USR_CRE*/         opdracht.USR_CRE,
                   /*TS_LW_UTC*/       sysdate,    -- Moet verkeerd opdat de update de TS_LW niet wist!
                   /*USR_LW*/          opdracht.USR_LW,
                   /*VERSIE*/          0
                   );

        -- Alle opdrachten krijgen een AANGEMAAKT opdracht_historiek
        insert into SCH_OPDRACHTEN.OPDRACHT_HISTORIEK(ID, OPDRACHT_ID, STATUS, STATUS_VANAF, TS_CRE_UTC, USR_CRE, TS_LW_UTC, USR_LW)
        VALUES(SCH_OPDRACHTEN.OPDRACHT_HISTORIEK_SEQ.nextval, opdracht.id, 'AANGEMAAKT', CAST(opdracht.DTM_CRE as DATE),
               CAST(opdracht.DTM_CRE as TIMESTAMP(4)), opdracht.USR_CRE, CAST(opdracht.DTM_CRE as TIMESTAMP(4)), opdracht.USR_CRE)
               returning id into opdracht_historiek_id;
        -- Afgesloten opdrachten krijgen een recentere AFGESLOTEN opdracht_historiek
        IF opdracht.AFSLUITDATUM IS NOT NULL
        THEN insert into SCH_OPDRACHTEN.OPDRACHT_HISTORIEK(ID, OPDRACHT_ID, STATUS, STATUS_VANAF, TS_CRE_UTC, USR_CRE, TS_LW_UTC, USR_LW, STATUS_OPMERKING)
             VALUES(SCH_OPDRACHTEN.OPDRACHT_HISTORIEK_SEQ.nextval, opdracht.id, 'AFGESLOTEN', CAST(opdracht.AFSLUITDATUM as DATE),
                    CAST(opdracht.AFSLUITDATUM as TIMESTAMP(4)), opdracht.USR_LW, CAST(opdracht.AFSLUITDATUM as TIMESTAMP(4)), opdracht.USR_LW, opdracht.AFSLUITOPMERKING)
               returning id into opdracht_historiek_id;
        END IF;

        -- Opdracht verwijst terug naar zijn recentste status/historiek. Dit is op dit punt de opdracht_historiek met het hoogste id, voor de opdracht met hoogste id.
        -- Tegelijk wordt de TS_LW rechtgezet.
        update SCH_OPDRACHTEN.OPDRACHT
        set STATUS = opdracht_historiek_id ,
            TS_LW_UTC = CAST(opdracht.DTM_LW - INTERVAL '2' HOUR as TIMESTAMP(4))
        where ID = opdracht.id;

        aantalVerwerkt := aantalVerwerkt + 1;
        totaalAantalVerwerkt := totaalAantalVerwerkt +1;
        COMMIT;

    END LOOP;

    execute immediate 'DROP SEQUENCE SCH_OPDRACHTEN.OPDRACHT_SEQ';
    execute immediate 'CREATE SEQUENCE SCH_OPDRACHTEN.OPDRACHT_SEQ START WITH     2000000  INCREMENT BY   1 NOCACHE NOCYCLE';

    COMMIT;
END;