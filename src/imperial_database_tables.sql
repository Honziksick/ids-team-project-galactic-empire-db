/*
 * Téma:   Zadání IUS 2023/24 – Galaktické impérium (68)
 *
 * Autoři: Jan Kalina    <xkalinj00>
 *         David Krejčí  <xkrejcd00>
 *
 * Datum:  28.03.2025
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
    subtyp_uzivatele           VARCHAR2(20) CHECK (subtyp_uzivatele IN ('rytir', 'velitel')),
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
    -- Jedi musí mít  subtyp 'rytir' nebo 'velitel'!
    IF :NEW.typ_uzivatele = 'jedi' AND :NEW.subtyp_uzivatele NOT IN ('rytir', 'velitel') THEN
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

CREATE TABLE Padawan
(
    id_mistra    NUMBER,
    id_padawana  NUMBER,
    padawanem_od DATE,
    padawanem_do DATE,
    PRIMARY KEY (id_mistra, id_padawana), -- Unární vztah má složený primární klíč
    CHECK (padawanem_od < padawanem_do)   -- Kontrola, že datum začátku je před datem konce
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
    id_velitele   NUMBER
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


-- **************************************** --
-- Tabulka Rozkaz (rozkazy plněný flotilou) --
-- **************************************** --

-- Poznámka ke změně oporti původnímu ER diagramu:
-- Atribut 'Popis' byl změněn (přejmenován) na 'zneni'
CREATE TABLE Rozkaz
(
    id_rozkazu     NUMBER PRIMARY KEY,
    typ_rozkazu    VARCHAR2(30),
    zneni          CLOB,
    datum_vydani   DATE,
    termin_splneni DATE,
    CHECK (datum_vydani <= termin_splneni), -- Kontrola, že datum vydání rozkazu je před/roven termínem splnění
    stav_rozkazu   VARCHAR2(30) CHECK (stav_rozkazu IN ('nový', 'rozpracovaný', 'splněný', 'zrušený')),
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
    stav_lode  VARCHAR2(30) CHECK (stav_lode IN ('nová', 'používaná', 'poškozená', 'zničena')),
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

-- Trigger pro tabulku Svetelny_mec (id_mece)
CREATE OR REPLACE TRIGGER trg_mece_id
    BEFORE INSERT
    ON Svetelny_mec
    FOR EACH ROW
BEGIN
    :NEW.id_mece := seq_mece_id.NEXTVAL;
END;

-- Trigger pro tabulku Flotila (id_flotily)
CREATE OR REPLACE TRIGGER trg_flotily_id
    BEFORE INSERT
    ON Flotila
    FOR EACH ROW
BEGIN
    :NEW.id_flotily := seq_flotily_id.NEXTVAL;
END;

-- Trigger pro tabulku Lod (id_lode)
CREATE OR REPLACE TRIGGER trg_lode_id
    BEFORE INSERT
    ON Lod
    FOR EACH ROW
BEGIN
    :NEW.id_lode := seq_lode_id.NEXTVAL;
END;

-- Trigger pro tabulku Rozkaz (id_rozkazu)
CREATE OR REPLACE TRIGGER trg_rozkazy_id
    BEFORE INSERT
    ON Rozkaz
    FOR EACH ROW
BEGIN
    :NEW.id_rozkazu := seq_rozkazy_id.NEXTVAL;
END;

-- Trigger pro tabulku Planetarni_system (id_systemu)
CREATE OR REPLACE TRIGGER trg_system_id
    BEFORE INSERT
    ON Planetarni_system
    FOR EACH ROW
BEGIN
    :NEW.id_systemu := seq_system_id.NEXTVAL;
END;

-- Trigger pro tabulku Planeta (id_planety)
CREATE OR REPLACE TRIGGER trg_planeta_id
    BEFORE INSERT
    ON Planeta
    FOR EACH ROW
BEGIN
    :NEW.id_planety := seq_planeta_id.NEXTVAL;
END;

-- Trigger pro tabulku Hvezda (id_hvezdy)
CREATE OR REPLACE TRIGGER trg_hvezda_id
    BEFORE INSERT
    ON Hvezda
    FOR EACH ROW
BEGIN
    :NEW.id_hvezdy := seq_hvezda_id.NEXTVAL;
END;

-- Trigger pro tabulku Chemicky_prvek (id_prvku)
CREATE OR REPLACE TRIGGER trg_prvek_id
    BEFORE INSERT
    ON Chemicky_prvek
    FOR EACH ROW
BEGIN
    :NEW.id_prvku := seq_prvek_id.NEXTVAL;
END;


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
INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        'Tatoo I',
        'žlutý trpaslík');

INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        'Naboo Sun',
        'žlutý trpaslík');

INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        'Coruscant Prime',
        'modrý obr');

INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        'Hoth Star',
        'červený obr');

INSERT INTO Hvezda (id_hvezdy, id_systemu, nazev_hvezdy, typ_hvezdy)
VALUES (seq_hvezda_id.NEXTVAL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        'Dagobah Star',
        'červený trpaslík');

-- Vkládání dat do tabulky Planeta (planety v jednotlivých systémech)
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        seq_planeta_id.NEXTVAL,
        'Tatooine',
        'terestrická');

----- Systém 'Naboo' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        seq_planeta_id.NEXTVAL,
        'Naboo',
        'terestrická');

INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        seq_planeta_id.NEXTVAL,
        'Remine',
        'plynný obr');

INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        seq_planeta_id.NEXTVAL,
        'Bippa',
        'trpasličí planeta');

----- Systém 'Coruscant' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        seq_planeta_id.NEXTVAL,
        'Coruscant',
        'terestrická');

INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        seq_planeta_id.NEXTVAL,
        'Sankar',
        'exoplaneta');

----- Systém 'Hoth' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        seq_planeta_id.NEXTVAL,
        'Hoth',
        'ledový obr');

INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        seq_planeta_id.NEXTVAL,
        'Hoth II',
        'terestrická');

----- Systém 'Dagobah' -----
INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        seq_planeta_id.NEXTVAL,
        'Dagobah',
        'terestrická');

INSERT INTO Planeta (id_systemu, id_planety, nazev_planety, typ_planety)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        seq_planeta_id.NEXTVAL,
        'Bogden',
        'exoplaneta');

-- Vkládání dat do tabulky Chemicky_prvek (chemické prvky)
INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Vodík', 'H');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Helium', 'He');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Carbon', 'C');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Oxygen', 'O');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Nitrogen', 'N');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Iron', 'Fe');

INSERT INTO Chemicky_prvek (id_prvku, nazev_prvku, znacka_prvku)
VALUES (seq_prvek_id.NEXTVAL, 'Aluminum', 'Al');

-- Vkládání složení planety 'Tatooine'
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Vodík'),
        74.20000);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Helium'),
        24.30000);

-- Vkládání složení hvězdy 'Tatoo I'
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Tatoo I'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Vodík'),
        90.20000);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Tatoo I'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE nazev_prvku = 'Helium'),
        9.80000);

-- Vkládání složení hvězdy 'Naboo Sun' (88 % H, 10 % He, 2 % Fe)
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Naboo Sun'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        88.0);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Naboo Sun'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'He'),
        10.0);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Naboo Sun'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'Fe'),
        2.0);

-- Vkládání složení hvězdy 'Coruscant Prime' (70 % H, 25 % He, 5 % C)
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Coruscant Prime'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        70.0);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Coruscant Prime'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'He'),
        25.0);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Coruscant Prime'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'C'),
        5.0);

-- Vkládání složení hvězdy 'Hoth Star' (92 % H, 7 % He, 1 % O)
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Hoth Star'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        92.0);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Hoth Star'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'He'),
        7.0);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Hoth Star'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'O'),
        1.0);

-- Vkládání složení hvězdy 'Dagobah Star' (60 % H, 35 % He, 5 % N)
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Dagobah Star'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        60.0);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Dagobah Star'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'He'),
        35.0);
INSERT INTO Slozeni_hvezdy (id_systemu, id_hvezdy, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_hvezdy FROM Hvezda WHERE nazev_hvezdy = 'Dagobah Star'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'N'),
        5.0);

-- ***********************
-- Vkládání složení nových planet (každá planeta má alespoň 2 prvky)
-- ***********************

-- Pro planetu 'Naboo' – příklad: 20 % Vodík, 10 % Oxygen
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Naboo'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'H'),
        20.0);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Naboo'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'O'),
        10.0);

-- Pro planetu 'Remine' – příklad: 40 % Nitrogen, 5 % Aluminum
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Remine'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'N'),
        40.0);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Remine'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'Al'),
        5.0);

-- Pro planetu 'Bippa' – příklad: 12 % Carbon, 3 % Iron
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Bippa'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'C'),
        12.0);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Bippa'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'Fe'),
        3.0);

-- Pro planetu 'Coruscant' – příklad: 25 % Carbon, 10 % Oxygen
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'C'),
        25.0);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'O'),
        10.0);

-- Pro planetu 'Hoth' – příklad: 30 % Nitrogen, 2 % Iron
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'N'),
        30.0);
INSERT INTO Slozeni_planety (id_systemu, id_planety, id_prvku, zastoupeni_prvku)
VALUES ((SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'),
        (SELECT id_prvku FROM Chemicky_prvek WHERE znacka_prvku = 'Fe'),
        2.0);

-- ***********************
-- Vkládání dat do tabulky Uzivatel (uživatelé - jedi a imperátor)
-- ***********************
INSERT INTO Uzivatel (id_uzivatele, jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES (seq_uzivatel_id.NEXTVAL,
        'Obi-Wan', 'Kenobi',
        'jedi', 'rytir',
        'člověk',
        13400,
        TO_DATE('57-03-11', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

INSERT INTO Uzivatel (id_uzivatele, jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES (seq_uzivatel_id.NEXTVAL,
        'Mace', 'Windu',
        'jedi', 'velitel',
        'člověk',
        15000,
        TO_DATE('72-05-01', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

INSERT INTO Uzivatel (id_uzivatele, jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES (seq_uzivatel_id.NEXTVAL,
        'Sheev', 'Palpatine',
        'imperator', NULL,
        'člověk',
        NULL,
        TO_DATE('82-01-01', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

-- Vkládání dat pro Lukea Skywalkera (jedi rytir) – loď bude později nastavena
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Luke', 'Skywalker',
        'jedi', 'rytir',
        'člověk',
        15000,
        TO_DATE('19-05-04', 'YY-MM-DD'),
        (SELECT id_lode FROM Lod WHERE nazev_lode = 'Millennium Falcon'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

-- Vkládání dat pro Yodu (jedi velitel)
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Minch', 'Yoda',
        'jedi', 'velitel',
        'neznámá',
        18000,
        TO_DATE('80-01-01', 'YY-MM-DD'),
        NULL, -- Momentálně není přiřazena žádná loď
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Dagobah'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Dagobah'));

-- Vkládání dat pro Anakina Skywalkera (jedi rytir)
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Anakin', 'Skywalker',
        'jedi', 'rytir',
        'člověk',
        20000,
        TO_DATE('41-01-01', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Tatoo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Tatooine'));

-- Vkládání dat pro Darth Vadera (jedi rytir, zde uvádíme i speciální rasu)
INSERT INTO Uzivatel (jmeno, prijmeni, typ_uzivatele, subtyp_uzivatele, rasa, mnozstvi_midichlorianu,
                      narozeniny, lod_kde_se_nachazi, planetarni_system_narozeni, planeta_narozeni)
VALUES ('Darth', 'Vader',
        'jedi', 'rytir',
        'kyborg',
        NULL,
        TO_DATE('41-01-01', 'YY-MM-DD'),
        NULL,
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'));

-- ***********************
-- Vkládání dat do tabulky Flotila (flotily)
-- ***********************

-- Vkládání flotily 'Naboo Defense Fleet' s dočasným velitelským uživatelem (Mace Windu)
INSERT INTO Flotila (id_flotily, nazev_flotily, id_systemu, id_planety, id_velitele)
VALUES (seq_flotily_id.NEXTVAL,
        'Naboo Defense Fleet',
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Naboo'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo')),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Mace' AND prijmeni = 'Windu'));

-- Vkládání flotily 'Coruscant Home Fleet'
INSERT INTO Flotila (id_flotily, nazev_flotily, id_systemu, id_planety, id_velitele)
VALUES (seq_flotily_id.NEXTVAL,
        'Coruscant Home Fleet',
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Coruscant'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant')),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Mace' AND prijmeni = 'Windu'));

-- Vkládání flotily 'Hoth Invasion Fleet'
INSERT INTO Flotila (id_flotily, nazev_flotily, id_systemu, id_planety, id_velitele)
VALUES (seq_flotily_id.NEXTVAL,
        'Hoth Invasion Fleet',
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety
         FROM Planeta
         WHERE nazev_planety = 'Hoth'
           AND id_systemu = (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth')),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Mace' AND prijmeni = 'Windu'));

-- ***********************
-- Vkládání dat do tabulky Lod (lodě)
-- ***********************

-- Vkládání lodí do flotily 'Naboo Defense Fleet'
INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Theed Guardian',
        'korveta',
        'nová',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Naboo Defense Fleet'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Naboo'));

INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Royal Cruiser',
        'křižník',
        'používaná',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Naboo Defense Fleet'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Naboo'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Naboo'));

-- Vkládání lodí do flotily 'Coruscant Home Fleet'
INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Defender One',
        'stíhačka',
        'nová',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Coruscant Home Fleet'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'));

INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Pride of Coruscant',
        'bitevní loď',
        'používaná',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Coruscant Home Fleet'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'));

-- Vkládání lodí do flotily 'Hoth Invasion Fleet'
INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Snowpiercer',
        'transportní loď',
        'nová',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Hoth Invasion Fleet'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'));

INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Frost Blade',
        'fregata',
        'používaná',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Hoth Invasion Fleet'),
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Hoth'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Hoth'));

-- Bonus: Vytvoření slavné "Millennium Falcon" – loď bez přiřazené flotily, kotví na Coruscantu
INSERT INTO Lod (id_lode, nazev_lode, typ_lode, stav_lode, id_flotily, id_systemu, id_planety)
VALUES (seq_lode_id.NEXTVAL,
        'Millennium Falcon',
        'nákladní loď',
        'používaná',
        NULL, -- Není přiřazena žádná flotila
        (SELECT id_systemu FROM Planetarni_system WHERE nazev_systemu = 'Coruscant'),
        (SELECT id_planety FROM Planeta WHERE nazev_planety = 'Coruscant'));

-- ***********************
-- Vkládání dat do tabulky Svetelny_mec (světelné meče)
-- ***********************
INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Zelený hněv',
        'klasický',
        'zelená',
        'nový',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Obi-Wan' AND prijmeni = 'Kenobi'));

INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Skywalker Legacy',
        'klasický',
        'modrá',
        'lehce opotřebený',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Luke' AND prijmeni = 'Skywalker'));

INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Ataru Spark',
        'krátký',
        'zelená',
        'lehce opotřebený',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Yoda'));

INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Chosen One Blade',
        'klasický',
        'modrá',
        'opotřebený',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Anakin' AND prijmeni = 'Skywalker'));

INSERT INTO Svetelny_mec (id_mece, nazev_mece, typ_mece, barva_mece, stav_mece, id_uzivatele)
VALUES (seq_mece_id.NEXTVAL,
        'Hope Shard',
        'klasický',
        'zelená',
        'nový',
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Leia' AND prijmeni = 'Organa'));

-- ***********************
-- Vkládání dat do tabulky Padawan (vztahy mezi mistry a padawany)
-- ***********************
INSERT INTO Padawan (id_mistra, id_padawana, padawanem_od, padawanem_do)
VALUES ((SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Mace' AND prijmeni = 'Windu'),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Obi-Wan' AND prijmeni = 'Kenobi'),
        TO_DATE('50-01-01', 'YY-MM-DD'),
        TO_DATE('55-01-01', 'YY-MM-DD'));

-- Vztah mezi Obi-Wanem a Anakinem
INSERT INTO Padawan (id_mistra, id_padawana, padawanem_od, padawanem_do)
VALUES ((SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Obi-Wan' AND prijmeni = 'Kenobi'),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Anakin' AND prijmeni = 'Skywalker'),
        TO_DATE('52-01-01', 'YY-MM-DD'),
        TO_DATE('57-01-01', 'YY-MM-DD'));

-- Vztah mezi Yodou a Lukem
INSERT INTO Padawan (id_mistra, id_padawana, padawanem_od, padawanem_do)
VALUES ((SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Minch' AND prijmeni = 'Yoda'),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Luke' AND prijmeni = 'Skywalker'),
        TO_DATE('19-05-05', 'YY-MM-DD'),
        TO_DATE('21-05-05', 'YY-MM-DD'));

-- Vztah mezi Mace Winduem a Yodou (jen ukázka)
INSERT INTO Padawan (id_mistra, id_padawana, padawanem_od, padawanem_do)
VALUES ((SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Mace' AND prijmeni = 'Windu'),
        (SELECT id_uzivatele FROM Uzivatel WHERE jmeno = 'Minch' AND prijmeni = 'Yoda'),
        TO_DATE('54-01-01', 'YY-MM-DD'),
        TO_DATE('56-01-01', 'YY-MM-DD'));

-- ***********************
-- Vkládání dat do tabulky Rozkaz (rozkazy pro flotily)
-- ***********************

-- Rozkaz pro 'Naboo Defense Fleet'
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'obranný',
        'Chraňte hlavní město Theed proti možnému útoku.',
        TO_DATE('25-03-01', 'YY-MM-DD'),
        TO_DATE('25-03-10', 'YY-MM-DD'),
        'nový',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Naboo Defense Fleet'));

-- Rozkaz pro 'Naboo Defense Fleet' (průzkumný)
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'průzkumný',
        'Prozkoumat okolní sektory a hlásit nepřátelskou aktivitu.',
        TO_DATE('25-03-02', 'YY-MM-DD'),
        TO_DATE('25-03-15', 'YY-MM-DD'),
        'rozpracovaný',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Naboo Defense Fleet'));

-- Rozkaz pro 'Coruscant Home Fleet' (obléhací)
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'obléhací',
        'Zajistit ochranný perimetr kolem Coruscantu.',
        TO_DATE('25-04-01', 'YY-MM-DD'),
        TO_DATE('25-05-01', 'YY-MM-DD'),
        'nový',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Coruscant Home Fleet'));

-- Rozkaz pro 'Coruscant Home Fleet' (evakuační)
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'evakuační',
        'Evakuovat civilisty z ohrožených sektorů',
        TO_DATE('25-04-10', 'YY-MM-DD'),
        TO_DATE('25-04-20', 'YY-MM-DD'),
        'rozpracovaný',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Coruscant Home Fleet'));

-- Rozkaz pro 'Hoth Invasion Fleet' (invazní)
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'invazní',
        'Zaútočit na ledové pevnosti na povrchu planety Hoth.',
        TO_DATE('25-06-01', 'YY-MM-DD'),
        TO_DATE('25-06-15', 'YY-MM-DD'),
        'nový',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Hoth Invasion Fleet'));

-- Rozkaz pro 'Hoth Invasion Fleet' (zásobovací)
INSERT INTO Rozkaz (id_rozkazu, typ_rozkazu, zneni, datum_vydani, termin_splneni, stav_rozkazu, id_flotily)
VALUES (seq_rozkazy_id.NEXTVAL,
        'zásobovací',
        'Dodat zásoby pro pozemní jednotky.',
        TO_DATE('25-06-02', 'YY-MM-DD'),
        TO_DATE('25-06-20', 'YY-MM-DD'),
        'rozpracovaný',
        (SELECT id_flotily FROM Flotila WHERE nazev_flotily = 'Hoth Invasion Fleet'));

-- konec souboru --
