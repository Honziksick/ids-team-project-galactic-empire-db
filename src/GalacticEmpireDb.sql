/*
 * Téma:   Zadání IUS 2023/24 – Galaktické impérium (68)
 *
 * Autoři: Jan Kalina    <xkalinj00>
 *         David Krejčí  <xkrejcd00>
 *
 * Datum:  10.04.2025
 */

-- ******************************* --
-- Odstranění existujících objektů --
-- ******************************* --

-- Odstranění všech sekvencí používaných pro generování primárních klíčů
DROP SEQUENCE seq_uzivatel_id;
DROP SEQUENCE seq_mece_id;
DROP SEQUENCE seq_flotily_id;
DROP SEQUENCE seq_lode_id;
DROP SEQUENCE seq_rozkazy_id;
DROP SEQUENCE seq_system_id;
DROP SEQUENCE seq_planeta_id;
DROP SEQUENCE seq_hvezda_id;
DROP SEQUENCE seq_prvek_id;

-- Odstranění všech tabulek (včetně závislostí)
DROP TABLE Padawan CASCADE CONSTRAINTS;
DROP TABLE Svetelny_mec CASCADE CONSTRAINTS;
DROP TABLE Flotila CASCADE CONSTRAINTS;
DROP TABLE Lod CASCADE CONSTRAINTS;
DROP TABLE Rozkaz CASCADE CONSTRAINTS;
DROP TABLE Slozeni_planety CASCADE CONSTRAINTS;
DROP TABLE Slozeni_hvezdy CASCADE CONSTRAINTS;
DROP TABLE Planeta CASCADE CONSTRAINTS;
DROP TABLE Hvezda CASCADE CONSTRAINTS;
DROP TABLE Chemicky_prvek CASCADE CONSTRAINTS;
DROP TABLE Planetarni_system CASCADE CONSTRAINTS;
DROP TABLE Uzivatel CASCADE CONSTRAINTS;


-- ************************************* --
-- Vytvoření sekvencí pro primární klíče --
-- ************************************* --

--Automatické generování unikátních ID
CREATE SEQUENCE seq_uzivatel_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_mece_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_flotily_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_lode_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_rozkazy_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_system_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_planeta_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_hvezda_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_prvek_id START WITH 1 INCREMENT BY 1;


-- **************************** --
-- Tabulka Uzivatel (uživatelé) --
-- **************************** --

-- Poznámka: V našem případě jsme se rozhodli vztah generalizace/specializace
--           modelovat jako "typ 4" z přednášky (tedy vše do jedné tabulky s atributem
--           typu). Náš vztah generalizace/specializace je totiž disjunktní a totální.
--           Atrubut 'typ_uzivatele' určuje první stupeň dědičnosti na jedi a imperátora.
--           Atribut 'subtyp_uzivatele' určuje druhý stupeň dědičnosti, kdy jedi můžebýt
--           buď řadový rytíř nebo velitel (u imperátora je tento atribut NULL)
CREATE TABLE Uzivatel
(
    id_uzivatele               NUMBER PRIMARY KEY,
    jmeno                      VARCHAR2(100)                                               NOT NULL,
    prijmeni                   VARCHAR2(100)                                               NOT NULL,
    typ_uzivatele              VARCHAR2(20) CHECK (typ_uzivatele IN ('jedi', 'imperator')) NOT NULL,
    subtyp_uzivatele           VARCHAR2(20) CHECK (subtyp_uzivatele IN ('rytíř', 'velitel')),
    rasa                       VARCHAR2(100),
    mnozstvi_midichlorianu     NUMBER CHECK (mnozstvi_midichlorianu >= 0), -- Množství midichlorianů (kladná hodnota)
    narozeniny                 DATE,
    lod_kde_se_nachazi         NUMBER,
    planetarni_system_narozeni NUMBER,
    planeta_narozeni           NUMBER
    -- <<FK>> na planetu, kde se uživatel narodil
    -- <<FK>> na loď, kde se uživatel nachází
);

-- Trigger pro kontrolu správnosti hodnoty 'subtyp_uzivatele' podle 'typ_uzivatele'
CREATE OR REPLACE TRIGGER trg_check_subtyp_uzivatele
    BEFORE INSERT OR UPDATE
    ON Uzivatel
    FOR EACH ROW
BEGIN
    -- Jedi musí mít  subtyp 'rytíř' nebo 'velitel'!
    IF :NEW.typ_uzivatele = 'jedi' AND :NEW.subtyp_uzivatele NOT IN ('rytíř', 'velitel') THEN
        RAISE_APPLICATION_ERROR(-20001, 'Neplatný subtyp_uzivatele pro typ_uzivatele "jedi".');
        -- Imperátora musí být subtyp NULL!
    ELSIF :NEW.typ_uzivatele = 'imperator' AND :NEW.subtyp_uzivatele IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'subtyp_uzivatele musí být NULL pro typ_uzivatele "imperator".');
    END IF;
END;
-- Poznámka: V Oracle databázích je rozsah chybových kódů pro uživatelem definované
--           chyby od -20000 do -20999.


-- ********************************************************************* --
-- Tabulka Padawan (reprezentace unárního vztahu mezi mistry a padawany) --
-- ********************************************************************* --

-- Poznámka k datům:
-- Léta jsou ve formátu BBY (Před bitvou o Yavin), to znamená, že menší čislo je mladší
CREATE TABLE Padawan
(
    id_mistra    NUMBER,
    id_padawana  NUMBER,
    padawanem_od DATE,
    padawanem_do DATE,
    PRIMARY KEY (id_mistra, id_padawana), -- Unární vztah má složený primární klíč
    CHECK (padawanem_od <= padawanem_do)  -- Kontrola, že datum začátku je před datem konce
    -- <<FK>> na mistra (uživatele)
    -- <<FK>> na padawana (uživatele)
);

-- Trigger kontrolující, zda oba uživatelé mají typ 'jedi'
CREATE OR REPLACE TRIGGER trg_check_typ_uzivatele_padawan
    BEFORE INSERT OR UPDATE
    ON Padawan
    FOR EACH ROW
DECLARE
    var_typ_uzivatele_mistr   Uzivatel.typ_uzivatele%TYPE;
    var_typ_uzivatele_padawan Uzivatel.typ_uzivatele%TYPE;
BEGIN
    -- Získání typu mistra
    SELECT typ_uzivatele
    INTO var_typ_uzivatele_mistr
    FROM Uzivatel
    WHERE id_uzivatele = :NEW.id_mistra;

    -- Získání typu padawana
    SELECT typ_uzivatele
    INTO var_typ_uzivatele_padawan
    FROM Uzivatel
    WHERE id_uzivatele = :NEW.id_padawana;

    -- Kontrola, jestli mistr je jedi
    IF var_typ_uzivatele_mistr != 'jedi' THEN
        RAISE_APPLICATION_ERROR(-20001, 'id_mistra musí mít typ_uzivatele "jedi".');
    END IF;

    -- Kontrola, jestli padawan je jedi
    IF var_typ_uzivatele_padawan != 'jedi' THEN
        RAISE_APPLICATION_ERROR(-20002, 'id_padawana musí mít typ_uzivatele "jedi".');
    END IF;
END;
/

-- ***************************************** --
-- Tabulka Svetelny_mec (světelné meče jedi) --
-- ***************************************** --

-- Poznámka ke změně oporti původnímu ER diagramu:
-- Před: Vztah mezi mečem a jedi byl 0:N – meč může patřit až N jedi.
-- Po: Vztah mezi mečem a jedi je nyní 0:1 – meč může patřit maximálně jednomu jedi.
CREATE TABLE Svetelny_mec
(
    id_mece      NUMBER PRIMARY KEY,
    nazev_mece   VARCHAR2(50),
    typ_mece     VARCHAR2(30) CHECK (typ_mece IN
                                     ('klasický', 'dvojitý', 'křížový', 'inquisitorský',
                                      'tréninkový', 'prodloužený', 'krátký', 'šavlový')),
    barva_mece   VARCHAR2(20) CHECK (barva_mece IN
                                     ('modrá', 'zelená', 'červená', 'fialová', 'žlutá', 'bílá', 'černá')),
    stav_mece    VARCHAR2(20) CHECK (stav_mece IN
                                     ('nový', 'opotřebený', 'lehce opotřebený', 'silně opotřebený',
                                      'poničený bojem', 'ztracený', 'snězený Rancorem')),
    id_uzivatele NUMBER
    -- <<FK>> na uživatele, který meč vlastní
);


-- ********************************************** --
-- Tabulka Planetarni_system (planetární systémy) --
-- ********************************************** --

CREATE TABLE Planetarni_system
(
    id_systemu    NUMBER PRIMARY KEY,
    nazev_systemu VARCHAR2(100)
);


-- *************************************** --
-- Tabulka Chemicky_prvek (chemické prvky) --
-- *************************************** --

-- Poznámka ke změně oporti původnímu ER diagramu:
-- Atribut 'Symbol' byl změněn (přejmenován) na 'znacka_prvku'
CREATE TABLE Chemicky_prvek
(
    id_prvku     NUMBER PRIMARY KEY,
    nazev_prvku  VARCHAR2(50),
    znacka_prvku VARCHAR2(10) CHECK (REGEXP_LIKE(znacka_prvku, '^[A-Za-z]+$')) -- Značku prvku tvoří pouze písmena
);


-- ************************* --
-- Tabulka Planeta (planety) --
-- ************************* --

CREATE TABLE Planeta
(
    id_systemu    NUMBER,
    id_planety    NUMBER,
    nazev_planety VARCHAR2(50),
    typ_planety   VARCHAR2(30) CHECK (typ_planety IN
                                      ('terestrická', 'plynný obr', 'ledový obr',
                                       'trpasličí planeta', 'exoplaneta')),
    PRIMARY KEY (id_systemu, id_planety) -- Složený primární klíč (jde o <<weak>> entitu identifikovanou entitou planetárního systému)
    -- <<FK>> na planetární systém, kde se planeta nachází
);


-- ************************* --
-- Tabulka Flotila (flotily) --
-- ************************* --

CREATE TABLE Flotila
(
    id_flotily    NUMBER PRIMARY KEY,
    nazev_flotily VARCHAR2(50),
    id_systemu    NUMBER,
    id_planety    NUMBER,
    id_velitele   NUMBER UNIQUE
    -- <<FK>> na planetární systém, kde se flotila nachází
    -- <<FK>> na velitele flotily (uživatele)
);

-- Trigger pro kontrolu, že uživatel je skutečně subtypu velitel
CREATE OR REPLACE TRIGGER trg_check_velitel
    BEFORE INSERT OR UPDATE
    ON Flotila
    FOR EACH ROW
DECLARE
    var_subtyp_uzivatele Uzivatel.subtyp_uzivatele%TYPE;
BEGIN
    SELECT subtyp_uzivatele
    INTO var_subtyp_uzivatele
    FROM Uzivatel
    WHERE id_uzivatele = :NEW.id_velitele;

    IF var_subtyp_uzivatele != 'velitel' THEN
        RAISE_APPLICATION_ERROR(-20001, 'id_velitele musí mít subtyp_uzivatele "velitel".');
    END IF;
END;
/

-- **************************************** --
-- Tabulka Rozkaz (rozkazy plněný flotilou) --
-- **************************************** --

-- Poznámka k datům:
-- Léta jsou ve formátu BBY (Před bitvou o Yavin), to znamená, že menší čislo je mladší
-- Poznámka ke změně oporti původnímu ER diagramu:
-- Atribut 'Popis' byl změněn (přejmenován) na 'zneni'
CREATE TABLE Rozkaz
(
    id_rozkazu     NUMBER PRIMARY KEY,
    typ_rozkazu    VARCHAR2(30),
    zneni          CLOB,
    datum_vydani   DATE,
    termin_splneni DATE,
    CHECK ( datum_vydani <= termin_splneni), -- Kontrola, že datum vydání rozkazu je před/roven termínem splnění
    stav_rozkazu   VARCHAR2(30) CHECK (stav_rozkazu IN ('nový', 'rozpracovaný', 'splněný', 'selhaný', 'zrušený')),
    id_flotily     NUMBER
    -- <<FK>> na flotilu, která rozkaz plní
);


-- *************************** --
-- Tabulka Lod (vesmírné lodě) --
-- *************************** --

CREATE TABLE Lod
(
    id_lode    NUMBER PRIMARY KEY,
    nazev_lode VARCHAR2(50),
    typ_lode   VARCHAR2(30) CHECK (typ_lode IN
                                   ('stíhačka', 'bombardér', 'korveta', 'fregata', 'křižník', 'bitevní loď',
                                    'hvězdný destruktor', 'transportní loď', 'průzkumná loď', 'nákladní loď',
                                    'Hvězda smrti')),
    stav_lode  VARCHAR2(30) CHECK (stav_lode IN ('nová', 'používaná', 'poškozená', 'zničená')),
    id_flotily NUMBER,
    id_systemu NUMBER,
    id_planety NUMBER
    -- <<FK>> na planetu, kde byla loď vyrobena
    -- <<FK>> na flotilu, do které loď patří
);


-- *********************** --
-- Tabulka Hvezda (hvězdy) --
-- *********************** --

CREATE TABLE Hvezda
(
    id_hvezdy    NUMBER,
    id_systemu   NUMBER,
    nazev_hvezdy VARCHAR2(50),
    typ_hvezdy   VARCHAR2(30) CHECK (typ_hvezdy IN
                                     ('červený trpaslík', 'žlutý trpaslík', 'modrý obr', 'červený obr',
                                      'bílý trpaslík', 'neutronová hvězda', 'černá díra')),
    PRIMARY KEY (id_systemu, id_hvezdy) -- Složený primární klíč (jde o <<weak>> entitu identifikovanou entitou planetárního systému)
    -- <<FK>> na planetární systém, kde se hvězda nachází
);


-- ****************************************************** --
-- Tabulka Slozeni_planety (chemické složení planety v %) --
-- ****************************************************** --

CREATE TABLE Slozeni_planety
(
    id_planety       NUMBER,
    id_systemu       NUMBER,
    id_prvku         NUMBER,
    zastoupeni_prvku DECIMAL(8, 5),
    CHECK (zastoupeni_prvku > 0.00000 AND zastoupeni_prvku <= 100.00000), -- Hodnota musí být mezi 0 a 100 %
    PRIMARY KEY (id_systemu, id_planety, id_prvku)                        -- jde o atribut vztahu, proto se PK skládá z PK entity spojených tímto vztahem
    -- <<FK>> na planetu
    -- <<FK>> na chemický prvek, který tvoří složení
);

-- **************************************************** --
-- Tabulka Slozeni_hvezdy (chemické složení hvězdy v %) --
-- **************************************************** --

CREATE TABLE Slozeni_hvezdy
(
    id_hvezdy        NUMBER,
    id_systemu       NUMBER,
    id_prvku         NUMBER,
    zastoupeni_prvku DECIMAL(8, 5),
    CHECK (zastoupeni_prvku > 0.00000 AND zastoupeni_prvku <= 100.00000), -- Hodnota musí být mezi 0 a 100 %
    PRIMARY KEY (id_systemu, id_hvezdy, id_prvku)                         -- jde o atribut vztahu, proto se PK skládá z PK entity spojených tímto vztahem
    -- <<FK>> na hvězdu
    -- <<FK>> na chemický prvek, který tvoří složení
);

-- ************************* --
-- Přidání cizích klíčů (FK) --
-- ************************* --

-- Vztah mezi Uzivatel a Lod (udává, na jaké lodi se uživatel nachází)
ALTER TABLE Uzivatel
    ADD CONSTRAINT fk_jedi_lod FOREIGN KEY (lod_kde_se_nachazi) REFERENCES Lod (id_lode);

-- Vztah mezi Uzivatel a Planeta (planeta, kde se uživatel narodil)
ALTER TABLE Uzivatel
    ADD CONSTRAINT fk_jedi_planeta FOREIGN KEY (planetarni_system_narozeni, planeta_narozeni) REFERENCES Planeta (id_systemu, id_planety);

-- Vztah mezi Lod a Planeta (planeta, kde byla loď vyrobena)
ALTER TABLE Lod
    ADD CONSTRAINT fk_lod_planeta FOREIGN KEY (id_systemu, id_planety) REFERENCES Planeta (id_systemu, id_planety);

-- Vztah mezi Lod a Flotila (flotila, do jaké loď patří)
ALTER TABLE Lod
    ADD CONSTRAINT fk_lod_flotila FOREIGN KEY (id_flotily) REFERENCES Flotila (id_flotily);

-- Vztah mezi Flotila a Planeta (kolem které planety flotila obíhá)
ALTER TABLE Flotila
    ADD CONSTRAINT fk_flotila_planeta FOREIGN KEY (id_systemu, id_planety) REFERENCES Planeta (id_systemu, id_planety);

-- Vztah mezi Flotila a Uzivatel (kdo je velitelem flotily)
ALTER TABLE Flotila
    ADD CONSTRAINT fk_flotila_velitel FOREIGN KEY (id_velitele) REFERENCES Uzivatel (id_uzivatele);

-- Vztahy v tabulce Padawan (vztah mezi mistrem a padawanem)
ALTER TABLE Padawan
    ADD CONSTRAINT fk_mistr FOREIGN KEY (id_mistra) REFERENCES Uzivatel (id_uzivatele);
ALTER TABLE Padawan
    ADD CONSTRAINT fk_padawan FOREIGN KEY (id_padawana) REFERENCES Uzivatel (id_uzivatele);

-- Vztah mezi Svetelny_mec a Uzivatel (který jedi vlastní meč)
ALTER TABLE Svetelny_mec
    ADD CONSTRAINT fk_svetelny_mec_jedi FOREIGN KEY (id_uzivatele) REFERENCES Uzivatel (id_uzivatele);

-- Vztah mezi Hvezda a Planetarni_system (hvězda patří do systému)
ALTER TABLE Hvezda
    ADD CONSTRAINT fk_hvezda_system FOREIGN KEY (id_systemu) REFERENCES Planetarni_system (id_systemu);

-- Vztah mezi Slozeni_planety a Chemicky_prvek (složení v %)
ALTER TABLE Slozeni_planety
    ADD CONSTRAINT fk_slozeni_planety_planeta FOREIGN KEY (id_systemu, id_planety) REFERENCES Planeta (id_systemu, id_planety);
ALTER TABLE Slozeni_planety
    ADD CONSTRAINT fk_slozeni_planety_prvek FOREIGN KEY (id_prvku) REFERENCES Chemicky_prvek (id_prvku);

-- Vztah mezi Slozeni_hvezdy a Chemicky_prvek (složení v %)
ALTER TABLE Slozeni_hvezdy
    ADD CONSTRAINT fk_slozeni_hvezdy_hvezda FOREIGN KEY (id_systemu, id_hvezdy) REFERENCES Hvezda (id_systemu, id_hvezdy);
ALTER TABLE Slozeni_hvezdy
    ADD CONSTRAINT fk_slozeni_hvezdy_prvek FOREIGN KEY (id_prvku) REFERENCES Chemicky_prvek (id_prvku);

-- Vztah mezi Rozkaz a Flotila (rozkaz plní konkrétní flotila)
ALTER TABLE Rozkaz
    ADD CONSTRAINT fk_rozkaz_flotila FOREIGN KEY (id_flotily) REFERENCES Flotila (id_flotily);


-- ****************************************************** --
-- Triggery pro automatické generování ID pomocí sekvencí --
-- ****************************************************** --

-- Trigger pro tabulku Uzivatel (id_uzivatele)
CREATE OR REPLACE TRIGGER trg_uzivatel_id
    BEFORE INSERT
    ON Uzivatel
    FOR EACH ROW
BEGIN
    :NEW.id_uzivatele := seq_uzivatel_id.NEXTVAL;
END;
/

-- Trigger pro tabulku Svetelny_mec (id_mece)
CREATE OR REPLACE TRIGGER trg_mece_id
    BEFORE INSERT
    ON Svetelny_mec
    FOR EACH ROW
BEGIN
    :NEW.id_mece := seq_mece_id.NEXTVAL;
END;
/

-- Trigger pro tabulku Flotila (id_flotily)
CREATE OR REPLACE TRIGGER trg_flotily_id
    BEFORE INSERT
    ON Flotila
    FOR EACH ROW
BEGIN
    :NEW.id_flotily := seq_flotily_id.NEXTVAL;
END;
/

-- Trigger pro tabulku Lod (id_lode)
CREATE OR REPLACE TRIGGER trg_lode_id
    BEFORE INSERT
    ON Lod
    FOR EACH ROW
BEGIN
    :NEW.id_lode := seq_lode_id.NEXTVAL;
END;
/

-- Trigger pro tabulku Rozkaz (id_rozkazu)
CREATE OR REPLACE TRIGGER trg_rozkazy_id
    BEFORE INSERT
    ON Rozkaz
    FOR EACH ROW
BEGIN
    :NEW.id_rozkazu := seq_rozkazy_id.NEXTVAL;
END;
/

-- Trigger pro tabulku Planetarni_system (id_systemu)
CREATE OR REPLACE TRIGGER trg_system_id
    BEFORE INSERT
    ON Planetarni_system
    FOR EACH ROW
BEGIN
    :NEW.id_systemu := seq_system_id.NEXTVAL;
END;
/

-- Trigger pro tabulku Planeta (id_planety)
CREATE OR REPLACE TRIGGER trg_planeta_id
    BEFORE INSERT
    ON Planeta
    FOR EACH ROW
BEGIN
    :NEW.id_planety := seq_planeta_id.NEXTVAL;
END;
/

-- Trigger pro tabulku Hvezda (id_hvezdy)
CREATE OR REPLACE TRIGGER trg_hvezda_id
    BEFORE INSERT
    ON Hvezda
    FOR EACH ROW
BEGIN
    :NEW.id_hvezdy := seq_hvezda_id.NEXTVAL;
END;
/

-- Trigger pro tabulku Chemicky_prvek (id_prvku)
CREATE OR REPLACE TRIGGER trg_prvek_id
    BEFORE INSERT
    ON Chemicky_prvek
    FOR EACH ROW
BEGIN
    :NEW.id_prvku := seq_prvek_id.NEXTVAL;
END;
/

-- ************************ --
-- Seedování ukázkových dat --
-- ************************ --

-- Vkládání dat do tabulky Planetarni_system (planetární systémy)
INSERT INTO Planetarni_system (id_systemu, nazev_systemu)
VALUES (seq_system_id.NEXTVAL, 'Tatoo');

INSERT INTO Planetarni_system (id_systemu, nazev_systemu)
VALUES (seq_system_id.NEXTVAL, 'Naboo');

INSERT INTO Planetarni_system (id_systemu, nazev_systemu)
VALUES (seq_system_id.NEXTVAL, 'Coruscant');

INSERT INTO Planetarni_system (id_systemu, nazev_systemu)
VALUES (seq_system_id.NEXTVAL, 'Hoth');

INSERT INTO Planetarni_system (id_systemu, nazev_systemu)
VALUES (seq_system_id.NEXTVAL, 'Dagobah');

-- Vkládání dat do tabulky Hvezda (hvězdy patřící do příslušných systémů)
----- Systém 'Tatoo' -----
INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        'Tatoo I',
        'žlutý trpaslík');

INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        'Tatoo II',
        'žlutý trpaslík');

----- Systém 'Naboo' -----
INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        'Naboo',
        'žlutý trpaslík');

----- Systém 'Coruscant' -----
INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        'Coruscant Prime',
        'modrý obr');

----- Systém 'Hoth' -----
INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        'Hoth',
        'modrý obr');

----- Systém 'Dagobah' -----
INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        'Darlo',
        'bílý trpaslík');

-- Vkládání dat do tabulky Planeta (planety v jednotlivých systémech)
----- Systém 'Tatoo' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        seq_planeta_id.NEXTVAL,
        'Tatooine',
        'terestrická');

INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        seq_planeta_id.NEXTVAL,
        'Ohann',
        'plynný obr');

INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        seq_planeta_id.NEXTVAL,
        'Adriana',
        'plynný obr');

----- Systém 'Naboo' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        seq_planeta_id.NEXTVAL,
        'Naboo',
        'terestrická');

----- Systém 'Coruscant' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        seq_planeta_id.NEXTVAL,
        'Coruscant',
        'terestrická');

----- Systém 'Hoth' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        seq_planeta_id.NEXTVAL,
        'Hoth',
        'ledový obr');

INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        seq_planeta_id.NEXTVAL,
        'Jhas',
        'plynný obr');

----- Systém 'Dagobah' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        seq_planeta_id.NEXTVAL,
        'Dagobah',
        'terestrická');

-- Vkládání dat do tabulky Chemicky_prvek (chemické prvky)
INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Vodík', 'H');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Hélium', 'He');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Uhlík', 'C');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Kyslík', 'O');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Dusík', 'N');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Železo', 'Fe');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Hliník', 'Al');


-- Vkládání dat do tabulky Slozeni_hvezdy (chemické složení hvězd)
----- Hvězda 'Tatoo I' -----
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Tatoo I'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Vodík'),
        90.20000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Tatoo I'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Hélium'),
        9.80000);

----- Hvězda 'Tatoo II' -----
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Tatoo II'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Vodík'),
        89.10000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Tatoo II'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Hélium'),
        10.90000);

----- Hvězda 'Naboo' -----
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Naboo'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        88.00000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Naboo'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'He'),
        10.00000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Naboo'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'Fe'),
        2.00000);

----- Hvězda 'Coruscant Prime' -----
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Coruscant Prime'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        70.00000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Coruscant Prime'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'He'),
        25.00000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Coruscant Prime'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'C'),
        5.00000);

----- Hvězda 'Hoth' -----
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Hoth'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        92.00000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Hoth'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'He'),
        7.00000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Hoth'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'O'),
        1.00000);

----- Hvězda 'Darlo' -----
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Darlo'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        60.00000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Darlo'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'He'),
        35.00000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Darlo'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'N'),
        5.00000);

-- Vkládání dat do tabulky Slozeni_planety (chemické složení atmosféry planet)
----- Planeta 'Tatooine' -----
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Dusík'),
        74.20000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Kyslík'),
        25.80000);

----- Planeta 'Ohann' -----
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Ohann'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Vodík'),
        80.00000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Ohann'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Hélium'),
        20.00000);

----- Planeta 'Adriana' -----
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Adriana'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Vodík'),
        60.65000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Adriana'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Hélium'),
        39.35000);

----- Planeta 'Naboo' -----
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Naboo'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        20.00000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Naboo'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'N'),
        65.00000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Naboo'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'O'),
        15.00000);

----- Planeta 'Coruscant' -----
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        21.00000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'N'),
        67.00000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'O'),
        12.00000);

----- Planeta 'Hoth' -----
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        5.09000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'N'),
        69.00000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'O'),
        16.00000);

----- Planeta 'Dagobah' -----
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Dagobah'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        19.50000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Dagobah'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'N'),
        40.10000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Dagobah'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'O'),
        20.40000);

-- Vkládání dat do tabulky Uzivatel
----- Rytíř 'Obi-Wan Kenobi' -----
INSERT INTO Uzivatel (id_uzivatele, jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES (seq_uzivatel_id.NEXTVAL,
        'Obi-Wan', 'Kenobi',
        'jedi', 'velitel',
        'člověk',
        13400,
        TO_DATE('57-03-11', 'YY-MM-DD'),
        NULL,
        NULL,
        NULL);

----- Velitel 'Mace Windu' -----
INSERT INTO Uzivatel (id_uzivatele, jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES (seq_uzivatel_id.NEXTVAL,
        'Mace', 'Windu',
        'jedi', 'rytíř',
        'člověk',
        15000,
        TO_DATE('72-05-01', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

----- Imperátor 'Palpatine' -----
INSERT INTO Uzivatel (id_uzivatele, jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES (seq_uzivatel_id.NEXTVAL,
        'Sheev', 'Palpatine',
        'imperator', NULL,
        'člověk',
        NULL,
        TO_DATE('84-01-01', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Naboo'));

----- Rytíř 'Luke Skywalker' -----
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Luke', 'Skywalker',
        'jedi', 'rytíř',
        'člověk',
        15000,
        TO_DATE('19-05-04', 'YY-MM-DD'),
        (SELECT id_lode FROM Lod WHERE nazev_lode = 'Millennium Falcon'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

----- Velitel 'Yoda' -----
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Minch', 'Yoda',
        'jedi', 'velitel',
        'neznámá',
        18000,
        TO_DATE('896-10-02', 'YY-MM-DD'),
        NULL,
        NULL,
        NULL);

----- Rytíř 'Anakin Skywalker' -----
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Anakin', 'Skywalker',
        'jedi', 'rytíř',
        'člověk',
        25000,
        TO_DATE('41-01-01', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

----- Rytíř 'Darth Vader' -----
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Darth', 'Vader',
        'jedi', 'rytíř',
        'kyborg',
        25000,
        TO_DATE('41-01-01', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'));

-- Rytíř Generála Grievous
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Generál', 'Grievous',
        'jedi', 'velitel',
        'droid',
        0,
        TO_DATE('50-01-01', 'YY-MM-DD'),
        NULL,
        NULL,
        NULL);

-- Vkládání dat do tabulky Flotila
----- Flotila 'Nejvyšší Řád' -----
INSERT INTO Flotila (id_flotily, nazev_flotily, id_systemu, id_planety, id_velitele)
VALUES (seq_flotily_id.NEXTVAL,
        'Nejvyšší Řád',
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Tatooine'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo')),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Generál' AND prijmeni = 'Grievous'));

----- Flotila 'Otevřený Kruh' -----
INSERT INTO Flotila (id_flotily, nazev_flotily, id_systemu, id_planety, id_velitele)
VALUES (seq_flotily_id.NEXTVAL,
        'Otevřený Kruh',
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Naboo'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Obi-Wan' AND prijmeni = 'Kenobi'));

----- Flotila 'Námořnictvo Aliance Rebelů' -----
INSERT INTO Flotila (id_flotily, nazev_flotily, id_systemu, id_planety, id_velitele)
VALUES (seq_flotily_id.NEXTVAL,
        'Námořnictvo Aliance Rebelů',
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Hoth'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth')),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Minch' AND prijmeni = 'Yoda'));

-- Vkládání dat do tabulky Lod
----- Lodě flotily 'Nejvyšší Řád' -----
INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Hvězdný destruktor třídy Imperial I - 0001',
        'hvězdný destruktor',
        'používaná',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Nejvyšší Řád'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Naboo'));

INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Hvězdný destruktor třídy Imperial I - 0002',
        'hvězdný destruktor',
        'poškozená',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Nejvyšší Řád'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Naboo'));

INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Hvězdný destruktor třídy Imperial I - 0003',
        'hvězdný destruktor',
        'zničená',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Nejvyšší Řád'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Naboo'));

----- Lodě flotily 'Otevřený Kruh' -----
INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Vlajková loď Anakina Skywalkera',
        'hvězdný destruktor',
        'používaná',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Otevřený Kruh'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'));

INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Hvězdný destruktor třídy Venator - 0002',
        'hvězdný destruktor',
        'používaná',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Otevřený Kruh'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'));

INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Pýcha Corusantu',
        'bitevní loď',
        'používaná',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Otevřený Kruh'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'));

----- Lodě flotily 'Námořnictvo Aliance Rebelů' -----
INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Auric',
        'transportní loď',
        'nová',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Námořnictvo Aliance Rebelů'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'));

INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Ledová Čepel',
        'fregata',
        'používaná',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Námořnictvo Aliance Rebelů'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'));

----- Bez flotily 'Millennium Falcon' -----
INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Millennium Falcon',
        'nákladní loď',
        'používaná',
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

-- Vkládání dat do tabulky Svetelny_mec

INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Zelený hněv',
        'klasický',
        'zelená',
        'nový',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Obi-Wan' AND prijmeni = 'Kenobi'));

INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Odkaz Skywalkera',
        'klasický',
        'modrá',
        'lehce opotřebený',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Luke' AND prijmeni = 'Skywalker'));

INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Jisrka Ataru ',
        'krátký',
        'zelená',
        'lehce opotřebený',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Yoda'));

INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Ostří vyvoleného',
        'klasický',
        'modrá',
        'opotřebený',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Anakin' AND prijmeni = 'Skywalker'));

INSERT INTO SVETELNY_MEC (ID_MECE,
                          NAZEV_MECE,
                          TYP_MECE,
                          BARVA_MECE,
                          STAV_MECE,
                          ID_UZIVATELE)
VALUES (SEQ_MECE_ID.NEXTVAL,
        'Meč Qui-Gon Jinna',
        'klasický',
        'zelená',
        'lehce opotřebený',
        (SELECT ID_UZIVATELE
         FROM UZIVATEL
         WHERE
             JMENO =
             'Generál'
           AND
             PRIJMENI =
             'Grievous'));

INSERT INTO SVETELNY_MEC (ID_MECE,
                          NAZEV_MECE,
                          TYP_MECE,
                          BARVA_MECE,
                          STAV_MECE,
                          ID_UZIVATELE)
VALUES (SEQ_MECE_ID.NEXTVAL,
        'Meč Shaak Ti',
        'klasický',
        'modrá',
        'opotřebený',
        (SELECT ID_UZIVATELE
         FROM UZIVATEL
         WHERE
             JMENO =
             'Generál'
           AND
             PRIJMENI =
             'Grievous'));

INSERT INTO SVETELNY_MEC (ID_MECE,
                          NAZEV_MECE,
                          TYP_MECE,
                          BARVA_MECE,
                          STAV_MECE,
                          ID_UZIVATELE)
VALUES (SEQ_MECE_ID.NEXTVAL,
        'Meč Eeth Kotha',
        'klasický',
        'žlutá',
        'silně opotřebený',
        (SELECT ID_UZIVATELE
         FROM UZIVATEL
         WHERE
             JMENO =
             'Generál'
           AND
             PRIJMENI =
             'Grievous'));

INSERT INTO SVETELNY_MEC (ID_MECE,
                          NAZEV_MECE,
                          TYP_MECE,
                          BARVA_MECE,
                          STAV_MECE,
                          ID_UZIVATELE)
VALUES (SEQ_MECE_ID.NEXTVAL,
        'Meč Adi Galliové',
        'klasický',
        'modrá',
        'lehce opotřebený',
        (SELECT ID_UZIVATELE
         FROM UZIVATEL
         WHERE
             JMENO =
             'Generál'
           AND
             PRIJMENI =
             'Grievous'));

INSERT INTO SVETELNY_MEC (ID_MECE,
                          NAZEV_MECE,
                          TYP_MECE,
                          BARVA_MECE,
                          STAV_MECE,
                          ID_UZIVATELE)
VALUES (SEQ_MECE_ID.NEXTVAL,
        'Meč Ki-Adi-Mundiho',
        'klasický',
        'zelená',
        'poničený bojem',
        (SELECT ID_UZIVATELE
         FROM UZIVATEL
         WHERE
             JMENO =
             'Generál'
           AND
             PRIJMENI =
             'Grievous'));

INSERT INTO SVETELNY_MEC (ID_MECE,
                          NAZEV_MECE,
                          TYP_MECE,
                          BARVA_MECE,
                          STAV_MECE,
                          ID_UZIVATELE)
VALUES (SEQ_MECE_ID.NEXTVAL,
        'Meč Plo Koona',
        'klasický',
        'žlutá',
        'lehce opotřebený',
        (SELECT ID_UZIVATELE
         FROM UZIVATEL
         WHERE
             JMENO =
             'Generál'
           AND
             PRIJMENI =
             'Grievous'));

INSERT INTO SVETELNY_MEC (ID_MECE,
                          NAZEV_MECE,
                          TYP_MECE,
                          BARVA_MECE,
                          STAV_MECE,
                          ID_UZIVATELE)
VALUES (SEQ_MECE_ID.NEXTVAL,
        'Meč Depy Billaby',
        'klasický',
        'modrá',
        'opotřebený',
        (SELECT ID_UZIVATELE
         FROM UZIVATEL
         WHERE
             JMENO =
             'Generál'
           AND
             PRIJMENI =
             'Grievous'));

INSERT INTO SVETELNY_MEC (ID_MECE,
                          NAZEV_MECE,
                          TYP_MECE,
                          BARVA_MECE,
                          STAV_MECE,
                          ID_UZIVATELE)
VALUES (SEQ_MECE_ID.NEXTVAL,
        'Meč Luminary Unduli',
        'klasický',
        'zelená',
        'silně opotřebený',
        (SELECT ID_UZIVATELE
         FROM UZIVATEL
         WHERE
             JMENO =
             'Generál'
           AND
             PRIJMENI =
             'Grievous'));

-- Vkládání dat do tabulky Padawan
INSERT INTO Padawan (id_mistra, id_padawana, padawanem_od, padawanem_do)
VALUES ((SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Mace' AND prijmeni = 'Windu'),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Obi-Wan' AND prijmeni = 'Kenobi'),
        TO_DATE('39-03-04', 'YY-MM-DD'),
        TO_DATE('50-02-07', 'YY-MM-DD'));

INSERT INTO Padawan (id_mistra, id_padawana, padawanem_od, padawanem_do)
VALUES ((SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Obi-Wan' AND prijmeni = 'Kenobi'),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Anakin' AND prijmeni = 'Skywalker'),
        TO_DATE('26-10-05', 'YY-MM-DD'),
        TO_DATE('35-01-01', 'YY-MM-DD'));

INSERT INTO Padawan (id_mistra, id_padawana, padawanem_od, padawanem_do)
VALUES ((SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Minch' AND prijmeni = 'Yoda'),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Luke' AND prijmeni = 'Skywalker'),
        TO_DATE('10-05-05', 'YY-MM-DD'),
        TO_DATE('12-05-05', 'YY-MM-DD'));

INSERT INTO Padawan (id_mistra, id_padawana, padawanem_od, padawanem_do)
VALUES ((SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Minch' AND prijmeni = 'Yoda'),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Mace' AND prijmeni = 'Windu'),
        TO_DATE('52-01-03', 'YY-MM-DD'),
        TO_DATE('64-02-01', 'YY-MM-DD'));

-- Vkládání dat do tabulky Rozkaz
----- Rozkaz flotily 'Nejvyšší Řád' -----
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'obléhací',
        'Zajistěte perimetr pro obléhání planety Tatooine.',
        TO_DATE('25-03-11', 'YY-MM-DD'),
        NULL,
        'nový',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Nejvyšší Řád'));

----- Rozkazy flotily 'Otevřený Kruh' -----
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'obranný',
        'Chraňte hlavní město proti možnému útoku povstalců.',
        TO_DATE('25-03-01', 'YY-MM-DD'),
        TO_DATE('25-03-10', 'YY-MM-DD'),
        'splněný',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Otevřený Kruh'));

INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'průzkumný',
        'Prozkoumejte oblast sektoru Chommell a hlaste aktivitu povstalců.',
        TO_DATE('25-02-20', 'YY-MM-DD'),
        NULL,
        'rozpracovaný',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Otevřený Kruh'));

----- Rozkazy flotily 'Námořnictvo Aliance Rebelů' -----
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'invazní',
        'Zaútočte na hlavní město a osvoboďte ho od nadvlády Impéria.',
        TO_DATE('25-02-28', 'YY-MM-DD'),
        TO_DATE('25-03-09', 'YY-MM-DD'),
        'selhaný',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Námořnictvo Aliance Rebelů'));

INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'evakuační',
        'Evakuujte vojáky a civilisty z oblasti.',
        TO_DATE('25-03-09', 'YY-MM-DD'),
        NULL,
        'rozpracovaný',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Námořnictvo Aliance Rebelů'));

-- Aktualizace lodi, kde se uživatel nachází
UPDATE Uzivatel
SET lod_kde_se_nachazi = (SELECT id_lode FROM Lod WHERE nazev_lode = 'Pýcha Corusantu')
WHERE jmeno = 'Obi-Wan'
  AND prijmeni = 'Kenobi';

UPDATE Uzivatel
SET lod_kde_se_nachazi = (SELECT id_lode FROM Lod WHERE nazev_lode = 'Millennium Falcon')
WHERE jmeno = 'Luke'
  AND prijmeni = 'Skywalker';

UPDATE Uzivatel
SET lod_kde_se_nachazi = (SELECT id_lode FROM Lod WHERE nazev_lode = 'Ledová Čepel')
WHERE jmeno = 'Minch'
  AND prijmeni = 'Yoda';

UPDATE Uzivatel
SET lod_kde_se_nachazi = (SELECT id_lode FROM Lod WHERE nazev_lode = 'Vlajková loď Anakina Skywalkera')
WHERE jmeno = 'Anakin'
  AND prijmeni = 'Skywalker';

UPDATE Uzivatel
SET lod_kde_se_nachazi = (SELECT id_lode FROM Lod WHERE nazev_lode = 'Hvězdný destruktor třídy Imperial I - 0001')
WHERE jmeno = 'Generál'
  AND prijmeni = 'Grievous';

UPDATE Uzivatel
SET lod_kde_se_nachazi = (SELECT id_lode FROM Lod WHERE nazev_lode = 'Hvězdný destruktor třídy Imperial I - 0001')
WHERE jmeno = 'Darth'
  AND prijmeni = 'Vader';

UPDATE Uzivatel
SET lod_kde_se_nachazi = (SELECT id_lode FROM Lod WHERE nazev_lode = 'Millennium Falcon')
WHERE jmeno = 'Mace'
  AND prijmeni = 'Windu';


-- ************************************************************************** --
-- *                                                                        * --
-- *     SELECT dotazy zadané způsobem podobným půlsemestrální zkoušce      * --
-- *                                                                        * --
-- ************************************************************************** --

-- Kteří uživatelé (jedi) vlastní pojmenované světelné meče a jak se tyto meče
-- jmenují? Seřaďte uživatele podle příjmení sestupně. (jmeno, prijmeni, nazev_mece)
SELECT jmeno, prijmeni, nazev_mece
FROM Uzivatel NATURAL JOIN Svetelny_mec
WHERE typ_uzivatele = 'jedi' AND nazev_mece IS NOT NULL
ORDER BY prijmeni DESC;


-- Jaké flotily obíhají kolem jakých planet a kdo je jejich velitel?
-- (nazev_flotily, nazev_planety, jmeno_velitele, prijmeni_velitele)
SELECT f.nazev_flotily, p.nazev_planety, u.jmeno AS jmeno_velitele, u.prijmeni AS prijmeni_velitele
FROM Flotila f NATURAL JOIN Planeta p JOIN Uzivatel u ON f.id_velitele = u.id_uzivatele
WHERE u.subtyp_uzivatele = 'velitel';


-- Kolik světelných mečů vlastní jednotliví jedi? Seřaďte podle počtu mečů vzestupně.
-- (jmeno, prijmeni, pocet_mecu)
SELECT jmeno, prijmeni, COUNT(id_mece) AS pocet_mecu
FROM Uzivatel NATURAL LEFT JOIN Svetelny_mec
WHERE typ_uzivatele = 'jedi'
GROUP BY jmeno, prijmeni
ORDER BY pocet_mecu ASC;


-- Které planety mají chybně zadané složení atmosféry (tedy součet prvků v atmosféře
-- není 100 %) a kolik je jejich chybný součet? Seřaďte podle souctu zastoupení sestupně.
-- (nazev_planety, soucet_zastoupeni)
SELECT nazev_planety, SUM(zastoupeni_prvku) AS soucet_zastoupeni
FROM Planeta NATURAL JOIN Slozeni_planety NATURAL JOIN Chemicky_prvek
GROUP BY nazev_planety
HAVING SUM(zastoupeni_prvku) != 100
ORDER BY soucet_zastoupeni DESC;


-- Které planety mají ve své atmosféře zastoupený prvek s chemickou značkou "O"
-- v míře vyšší než 20%? (nazev_planety, nazev_prvku, zastoupeni_prvku)
SELECT nazev_planety, nazev_prvku, zastoupeni_prvku
FROM Planeta NATURAL JOIN Slozeni_planety NATURAL JOIN Chemicky_prvek
WHERE znacka_prvku = 'O' AND zastoupeni_prvku > 20;


-- Které hvězdy jsou složeny z alespoň jednoho chemického prvku se zastoupením
-- vyšším než 90 %? (nazev_hvezdy, znacka_prvku, nazev_prvku, zastoupeni_prvku)
SELECT DISTINCT nazev_hvezdy, znacka_prvku, nazev_prvku, zastoupeni_prvku
FROM Hvezda NATURAL JOIN Slozeni_hvezdy NATURAL JOIN Chemicky_prvek
WHERE zastoupeni_prvku > 90;


-- Kteří uživatelé se nacházejí na lodi "Millennium Falcon"? Seřaďtě uživatele
-- podle jejich subtypu sestupně? (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele)
SELECT jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele
FROM Uzivatel
WHERE lod_kde_se_nachazi IN (
    SELECT id_lode
    FROM Lod
    WHERE nazev_lode = 'Millennium Falcon'
);


-- Které rozkazy byly vydány flotilám, jejichž velitel vlastní více než jeden
-- světelný meč? Výsledek seřaďte sestupně podle názvu flotily.
-- (jmeno, prijmeni, nazev_flotily, typ_rozkazu, zneni, pocet_mecu)
SELECT u.jmeno, u.prijmeni, f.nazev_flotily, r.typ_rozkazu, r.zneni,
       (SELECT COUNT(*)
        FROM Svetelny_mec sm
        WHERE sm.id_uzivatele = u.id_uzivatele) AS pocet_mecu
FROM Rozkaz r
         JOIN Flotila f ON r.id_flotily = f.id_flotily
         JOIN Uzivatel u ON f.id_velitele = u.id_uzivatele
WHERE u.id_uzivatele IN (
    SELECT sm.id_uzivatele
    FROM Svetelny_mec sm
    GROUP BY sm.id_uzivatele
    HAVING COUNT(*) > 1
)
ORDER BY nazev_flotily DESC;


-- Kolik padawanů má každý mistr? (jmeno_mistra, prijmeni_mistra, pocet_padawanu)
SELECT u.jmeno AS jmeno_mistra, u.prijmeni AS prijmeni_mistra, COUNT(p.id_padawana) AS pocet_padawanu
FROM Uzivatel u JOIN Padawan p ON u.id_uzivatele = p.id_mistra
WHERE u.typ_uzivatele = 'jedi'
GROUP BY u.jmeno, u.prijmeni
ORDER BY pocet_padawanu DESC;


-- Jaké rozkazy byly vydány po 1. lednu 2025 a dosud nejsou splněny?
-- (typ_rozkazu, zneni_rozkazu, datum_vydani, stav_rozkazu)
SELECT typ_rozkazu, zneni AS zneni_rozkazu, datum_vydani, stav_rozkazu
FROM Rozkaz
WHERE datum_vydani > TO_DATE('2025-01-01', 'YYYY-MM-DD') AND stav_rozkazu != 'splněný';


-- Které flotily obíhají kolem planet, které jsou typu "terestrická"?
-- (nazev_flotily, nazev_planety)
SELECT nazev_flotily, nazev_planety
FROM Flotila NATURAL JOIN Planeta
WHERE typ_planety = 'terestrická';


-- Jaké je průměrné množství midichlorianu u uživatelů typu "jedi" podle jejich
-- subtypu? (subtyp_uzivatele, prumer_midichlorianu)
SELECT subtyp_uzivatele, AVG(mnozstvi_midichlorianu) AS prumer_midichlorianu
FROM Uzivatel
WHERE typ_uzivatele = 'jedi'
GROUP BY subtyp_uzivatele;


-- Které rozkazy jsou spojeny s flotilami, které vlastní loď obsahující v svém
-- názvu podřetězec "destruktor"? (typ_rozkazu, zneni_rozkazu, nazev_lode)
SELECT r.typ_rozkazu, r.zneni AS zneni_rozkazu, l.nazev_lode
FROM Rozkaz r
JOIN Flotila f ON r.id_flotily = f.id_flotily
JOIN Lod l ON f.id_flotily = l.id_flotily
WHERE l.nazev_lode LIKE '%destruktor%';


-- Kteří jedi vlastní světelný meč, ale k dnešnímu dni nemají žádného padawana?
-- (jmeno_jedi, prijmeni_jedi)
SELECT DISTINCT jmeno as jmeno_jedi, prijmeni AS prijmeni_jedi
FROM Uzivatel NATURAL JOIN Svetelny_mec
WHERE NOT EXISTS (
    SELECT 1
    FROM Padawan
    WHERE id_mistra = id_uzivatele
      AND SYSDATE BETWEEN padawanem_od AND padawanem_do
);


-- Kteří velitelé evidují ve své flotile alespoň jednu loď ve stavu "poškozená"
-- nebo "zničená"? (jmeno, prijmeni)
SELECT u.jmeno AS jmeno_velitele, u.prijmeni AS prijmeni_velitele
FROM Uzivatel u
WHERE EXISTS (
    SELECT 1
    FROM Flotila f
             JOIN Lod l ON f.id_flotily = l.id_flotily
    WHERE f.id_velitele = u.id_uzivatele
      AND l.stav_lode IN ('poškozená', 'zničena')
);

-- konec souboru --
