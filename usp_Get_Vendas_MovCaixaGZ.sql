/*
====================================================================================================================================================================================
Procedimento para substiruir a SP "usp_movcaixagz", devido ao refinamento de codigo e levando em conta que os dados estao unificados entre o BD da GZ
e Integros, onde a tabela movcaixagz do Integros continha dados apenas a partir de Set/2018;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
25/04/2025 WILLIAM
	- Inclusao do "COLLATE DATABASE_DEFAULT" no filtro por "status", para atender BD da Tanby CD;
24/04/2025 WILLIAM
    - SP renomeada para "usp_Get_Vendas_MovCaixaGZ";
25/02/2025 WILLIAM
    - Criacao;
====================================================================================================================================================================================
*/
ALTER PROCEDURE [dbo].[usp_Get_Vendas_MovCaixaGZ] 
    @pdataDe date = null, 
    @pdataAte date  = null,
    @pCaixas varchar(50) = '',
    @pStatus varchar(50) = '', 
    @pCancelados char(1) = ''
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    DECLARE @codigoEmpresa smallint, @dataDe date, @dataAte date, @Caixas varchar(50), @Status varchar(50), @Cancelados char(1),
            @empresaGzLoja int, @cmdSQL nvarchar (MAX), @ParmDef nvarchar (500);

	-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @dataDe = (SELECT ISNULL(@pdataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pdataAte, GETDATE()));
    SET @Caixas = RTRIM(LTRIM(@pCaixas));
    SET @Status = RTRIM(LTRIM(@pStatus));
    SET @Cancelados = UPPER(@pCancelados);
    
-- Atribuicoes locais
    SET @empresaGzLoja = CONVERT(INT, dbo.ufn_Get_Parametro(1431));

-- Uso da funcao split, para as clausulas IN()
    -- Caixas
	IF OBJECT_ID('tempdb.dbo.#CAIXAS') IS NOT NULL
		DROP TABLE #CAIXAS;
    SELECT 
		elemento as valor
	INTO #CAIXAS FROM fSplit(@Caixas, ',');    
    IF @Caixas = ''
        DELETE #CAIXAS;
    -- Status
	IF OBJECT_ID('tempdb.dbo.#STATUS') IS NOT NULL
		DROP TABLE #STATUS;
    SELECT 
		elemento as valor
	INTO #STATUS FROM fSplit(@Status, ',');    
    IF @Status = ''
        DELETE #STATUS;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Obtem os registros de cupons utilizando query dinamica, criando a tabela temporaria global ##MOVCAIXAGZ

	IF OBJECT_ID('tempdb.dbo.##MOVCAIXAGZ') IS NOT NULL
	   DROP TABLE ##MOVCAIXAGZ;
	
	CREATE TABLE ##MOVCAIXAGZ (
        data datetime, 
        hora varchar(5) ,
        loja int, 
        caixa int,
        nfce_chave varchar(44), 
        cupom int,
        status char(2),
        item int,
        cdprod char(15),
        quant decimal(9,3),
        preco decimal(13,3),
        valortot decimal(13,2),
        desccupom decimal(13,3),
        abatpgto decimal(13,2),
        descitem decimal(13,3),
        acrescupom decimal(13,3),
        acresitem decimal(13,3),
        valorliq decimal(13,2),
        tipopagto char(3) ,
        tributacao decimal(5,2),
        cgc varchar(19) ,
        banco char(3),
        agencia char(7) ,
        cancelado char(1) ,
        cstpis char(2),
        aliqpis decimal(9,2),
        cstcofins char(2) ,
        aliqcofins decimal(9,2),
        precocusto decimal(13,3),
        datahoraproc datetime,
        sitnf int,
        numeronf int,
        serienf int,
        cliente int,
        vendedor int
        )
	
        SET @cmdSQL = N'
			
		INSERT INTO ##MOVCAIXAGZ
			
		SELECT 
            data, 
            hora collate database_default as hora,
            loja,
            caixa,
            nfce_chave collate database_default as nfce_chave,
            cupom,
            status,
            item,
            cdprod,
            quant,
            preco,
            valortot,
            desccupom,
            abatpgto,
            descitem,
            acrescupom,
            acresitem,
            valortot - desccupom - abatpgto - descitem + acrescupom + acresitem as valorliq, 
            tipopagto collate database_default as tipopagto,
            convert(decimal(5,2),case when tributacao = ''''  then ''.00'' else substring(tributacao,2,5) end) as tributacao,
            cgc collate database_default as cgc,
            banco collate database_default as banco,
            case when substring(banco,2,2) <> '''' and status = 01
                then
                    case when substring(banco,2,2) = ''60''
                        then ''5.405''
                        else ''5.102''
                    end
                else ''''
            end collate database_default as agencia,
            cancelado collate database_default as cancelado,
            cstpis collate database_default as cstpis,
            aliqpis,
            cstcofins COLLATE DATABASE_DEFAULT as cstcofins,
            aliqcofins,
            precocusto,
            datahoraproc,
            sitnf,
            numeronf,
            serienf,
            cliente,
            vendedor
			
		FROM movcaixagz (NOLOCK)
		
        WHERE
            loja = @empresaGzLoja AND
		    data BETWEEN @dataDe AND @dataAte            
        '
        +
        IIF(@Cancelados = 'S', ' AND cancelado = ''S''', IIF(@Cancelados = 'N', ' AND cancelado = ''''', ''))
        +
        IIF(@Status = '', '', ' AND status COLLATE DATABASE_DEFAULT IN(SELECT valor FROM #STATUS)')
        +
        IIF(@Caixas = '', '', ' AND caixa IN(SELECT valor FROM #CAIXAS)')
        +
		'
		ORDER BY 
            loja,
		    data,
		    nfce_chave,
		    status,
		    cancelado,
		    item
        '
			
	-- Executa a Query dinaminca
	SET @ParmDef = N'@empresaGzLoja int, @dataDe date, @dataAte date'

	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaGzLoja, @dataDe, @dataAte	    
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Tabela final
/*
    SELECT 
        * 
    FROM ##MOVCAIXAGZ (NOLOCK)
*/    
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END
GO