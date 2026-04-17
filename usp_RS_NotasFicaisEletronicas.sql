/*
======================================================================================================================================================
Script do Report Server					Notas ficais eletronicas
======================================================================================================================================================
										Histórico de alterações
======================================================================================================================================================
Data		Por							
Descrição
******************************************************************************************************************************************************
15/08/2024	ANDERSON WILLIAM			
- Uso da função "RetiraAcento_V" para retirar os caracteres especiais e acentos que podem dar erro ao exportar para EXCEL;

14/08/2024	ANDERSON WILLIAM
- Utilização dos atributos ENFBASICMS e ENFVALICMS, em vez de obter dos itens de cada tipo de nota(TBS0671, TBS1431, TBS1172, TBS0591),
dessa forma teremos um aumento de performance em obter os dados;

12/08/2024	ANDERSON WILLIAM			
- Conversão para Stored Procedure;
******************************************************************************************************************************************************
*/
--alter proc [dbo].usp_RS_NotasFicaisEletronicas(
create proc [dbo].usp_RS_NotasFicaisEletronicas(
	@empcod smallint,
	@dataDe date,
	@dataAte date = null,
	@NotaDe int,
	@NotaAte int = 0,
	@DesRemCod int,
	@DesRemNom varchar(60),
	@DesRemCnpjCPF varchar(14),
	@gruposVendedor varchar(500),
	@codigoVendedor varchar(800),
	@estadosUF varchar(max),
	@TiposDoc varchar(10),
	@FinalEmi varchar(100),
	@Situacao varchar(500),
	@Series varchar(100),
	@chaveAcesso varchar(44)
	)
as
begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declaraçoes das variaveis locais

	DECLARE	@empresaTBS080 smallint, @empresaTBS004 smallint, @Query nvarchar (MAX), @ParmDef nvarchar (500),
			@empresa smallint, @Data_De date, @Data_Ate date, @Nota_De int, @Nota_Ate int, @DesRem_Cod int,	@DesRem_Nom varchar(60), @DesRem_CnpjCPF varchar(14),
			@gVendedor varchar(500), @cVendedor varchar(800), @estados_UF varchar(max), @Tipos_Doc varchar(10), @Final_Emi varchar(100), @Situacao_NFe varchar(500),
			@Series_NFe varchar(100), @chaveAcesso_NFe varchar(44)
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuiçoes para desabilitar o "Parameter Sniffing" do SQL
	SET @empresa = @empcod
	SET @Data_De = @dataDe
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()))
	SET @Nota_De = @NotaDe
	SET @Nota_Ate = IIF(@NotaAte <= 0, 999999, @NotaAte)
	SET @DesRem_Cod = @DesRemCod
	SET @DesRem_Nom = UPPER(RTRIM(LTRIM(@DesRemNom)))
	SET @DesRem_CnpjCPF = @DesRemCnpjCPF
	SET @gVendedor = @gruposVendedor
	SET @cVendedor = REPLACE(@codigoVendedor, ' ', '')
	SET @estados_UF = @estadosUF
	SET @Tipos_Doc = @TiposDoc
	SET @Final_Emi = @FinalEmi
	SET @Situacao_NFe = @Situacao
	SET @Series_NFe = @Series
	SET @chaveAcesso_NFe = @chaveAcesso

	-- Quebra os filtros Multi-valores em tabelas via função "Split", para facilitar a cláusula "IN()"
	If object_id('TempDB.dbo.#GrupoVendedor') is not null
		DROP TABLE #GrupoVendedor;
    select elemento as [codgruven]
	Into #GrupoVendedor
    From fSplit(@gVendedor, ',')

	-- Vendedores do parâmetro
	If object_id('TempDB.dbo.#Vendedor_Parm') is not null
		DROP TABLE #Vendedores_Parm;
    select elemento as [codven]
	Into #Vendedores_Parm
    From fSplit(@cVendedor, ',')

	-- Estados da UF do parâmetro
	If object_id('TempDB.dbo.#Estados') is not null
		DROP TABLE #Estados;
    select elemento as [uf]
	Into #Estados
    From fSplit(@estados_UF, ',')

	-- Tipos de documentos do parâmetro: 0-Entrada;1-Sa�da
	If object_id('TempDB.dbo.#TiposDoc') is not null
		DROP TABLE #TiposDoc;
    select elemento as [tipdoc]
	Into #TiposDoc
    From fSplit(@Tipos_Doc, ',')

	-- Finalidade de emiss�o do parâmetro...
	If object_id('TempDB.dbo.#FinalEmi') is not null
		DROP TABLE #FinalEmi;
    select elemento as [finemi]
	Into #FinalEmi
    From fSplit(@Final_Emi, ',')

	-- Situa��o da NF-e
	If object_id('TempDB.dbo.#Situacao') is not null
		DROP TABLE #Situacao;
    select elemento as [sit]
	Into #Situacao
    From fSplit(@Situacao_NFe, ',')

	-- Situa��o da NF-e
	If object_id('TempDB.dbo.#SeriesNFe') is not null
		DROP TABLE #SeriesNFe;
    select elemento as [serie]
	Into #SeriesNFe
    From fSplit(@Series_NFe, ',')

	-- Verificar se a tabela � compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS004', @empresaTBS004 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS080', @empresaTBS080 output;

------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtém os códigos dos vendedores do parâmetro

	If object_id('tempdb.dbo.#V') is not null
		drop table #V;

	create table #V (VENCOD int)

	SET @Query = N'
				INSERT INTO #V

				SELECT 
				VENCOD 				
				
				FROM TBS004 (NOLOCK)
				WHERE
				VENEMPCOD = @empresaTBS004
				'
				+
				iif(@cVendedor = '', '', ' AND VENCOD IN (SELECT codven from #Vendedores_Parm)')
				+
				'UNION 
				SELECT TOP 1 0 FROM TBS001 (NOLOCK)
				'
				+
				iif(@cVendedor = '', '', ' WHERE 0 IN (SELECT codven from #Vendedores_Parm)')
			    
	-- Executa a Query din�minca(QD)
	SET @ParmDef = N'@empresaTBS004 smallint'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS004

--	SELECT * FROM #V
------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- TABELA DE VENDEDOR

	If object_id('tempdb.dbo.#Vendedores') is not null
	   drop table #Vendedores;

	SELECT 
	VENCOD as codigoVendedor,
	RIGHT('0000' + CAST(VENCOD AS VARCHAR(4)), 4)  + ' - ' + RTRIM(LTRIM(VENNOM)) AS nomeVendedor,
	B.GVECOD as codigoGrupo,
	ISNULL(RTRIM(LTRIM(STR(B.GVECOD))) + ' - ' + RTRIM(LTRIM(C.GVEDES)), '0 - SEM GRUPO') AS nomeGrupo

	INTO #Vendedores

	FROM TBS004 B (NOLOCK)
	LEFT JOIN TBS091 C (NOLOCK) ON B.GVECOD = C.GVECOD AND B.GVEEMPCOD = C.GVEEMPCOD

	WHERE
	VENEMPCOD = @empresaTBS004
	AND B.GVECOD IN (SELECT codgruven from #GrupoVendedor)
	AND VENCOD IN (SELECT VENCOD FROM #V)
	
	UNION

	SELECT
	TOP 1 
	0,
	'0 - SEM VENDEDOR' AS VENNOM,
	0,
	'0 - SEM GRUPO' AS GVDES

	FROM TBS001 (NOLOCK)

	WHERE
	0 IN (SELECT codgruven from #GrupoVendedor)
	AND 0 IN (SELECT VENCOD FROM #V) 

--  select * from #Vendedores
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	If object_id('tempdb.dbo.#NotasNfe') is not null	
		drop table #NotasNfe;

	-- SELECT TOP 0, para obter estrutura da tabela original
	SELECT TOP 0

	CASE ENFSIT
		WHEN 1 THEN 'Dig'
		WHEN 2 THEN 'DaV'
		WHEN 3 THEN 'DaI'
		WHEN 4 THEN 'Xml'
		WHEN 5 THEN 'Ass'
		WHEN 6 THEN 'Aut'
		WHEN 7 THEN 'Can'
		WHEN 8 THEN 'Den'
		WHEN 9 THEN 'Pro'
		WHEN 10 THEN 'Rej'
		WHEN 11 THEN 'Inu'
		ELSE ''
	END AS ENFSIT,
	ENFNUM,
	SNEEMPCOD,
	SNESER,
	CONVERT(DATE, ENFDATEMI) AS ENFDATEMI,
	ENFVALTOT,
	ENFCODDES,
	ENFDESREM,
	ENFCNPJCPF,
	ENFVENCOD,
	ENFTIPDOC,
	CASE ENFTIPDOC
		WHEN 0 THEN 'E'
		WHEN 1 THEN 'S'
		ELSE ''
	END ENFTIPDOCDES,
	ENFFINEMI,
	CASE ENFFINEMI
		WHEN 0 THEN '-'
		WHEN 1 THEN 'N'
		WHEN 2 THEN 'C'
		WHEN 3 THEN 'A'
		WHEN 4 THEN 'D'
		ELSE ''
	END ENFFINEMIDES,
	ENFCHAACE,
	ENFBASICMS,
	ENFVALICMS,
	RTRIM(ISNULL(C.MUNNOM, '')) AS MUNICIPIO,
	ENFESTDES,
	nomeVendedor

	INTO #NotasNfe

	FROM TBS080 (NOLOCK)
	LEFT JOIN TBS002 B (NOLOCK) ON CLICOD = ENFCODDES
	LEFT JOIN TBS003 C (NOLOCK) ON C.MUNCOD = B.MUNCOD
	LEFT JOIN #Vendedores D ON codigoVendedor = ENFVENCOD
	
	-- Monta a query dinamica
	SET @Query = N'
	INSERT INTO #NotasNfe

	SELECT 
	CASE ENFSIT
		WHEN 1 THEN ''Dig''
		WHEN 2 THEN ''DaV''
		WHEN 3 THEN ''DaI''
		WHEN 4 THEN ''Xml''
		WHEN 5 THEN ''Ass''
		WHEN 6 THEN ''Aut''
		WHEN 7 THEN ''Can''
		WHEN 8 THEN ''Den''
		WHEN 9 THEN ''Pro''
		WHEN 10 THEN ''Rej''
		WHEN 11 THEN ''Inu''
		ELSE ''''
	END AS ENFSIT,
	ENFNUM,
	SNEEMPCOD,
	SNESER,
	CONVERT(DATE, ENFDATEMI) AS ENFDATEMI,
	ENFVALTOT,
	ENFCODDES,
	RTRIM(LTRIM(dbo.RetiraAcento_V(ENFDESREM, 3))) AS ENFDESREM,
	ENFCNPJCPF,
	ENFVENCOD,
	ENFTIPDOC,
	CASE ENFTIPDOC
		WHEN 0 THEN ''E''
		WHEN 1 THEN ''S''
		ELSE ''''
	END ENFTIPDOCDES,
	ENFFINEMI,	
	CASE ENFFINEMI
		WHEN 0 THEN ''-''
		WHEN 1 THEN ''N''
		WHEN 2 THEN ''C''
		WHEN 3 THEN ''A''
		WHEN 4 THEN ''D''
		ELSE ''''
	END ENFFINEMIDES,
	ENFCHAACE,
	ISNULL(ENFBASICMS, 0) ENFBASICMS,
	ISNULL(ENFVALICMS, 0) ENFVALICMS,
	RTRIM(ISNULL(MUNNOM, '''')) AS MUNICIPIO,
	ENFESTDES,
	nomeVendedor

	FROM TBS080 (NOLOCK)
	LEFT JOIN TBS002 B (NOLOCK) ON CLICOD = ENFCODDES
	LEFT JOIN TBS003 C (NOLOCK) ON C.MUNCOD = B.MUNCOD
	LEFT JOIN #Vendedores D ON codigoVendedor = ENFVENCOD
 
	WHERE
	ENFEMPCOD = @empresaTBS080
	AND ENFDATEMI BETWEEN @Data_De AND @Data_Ate
	AND ENFNUM BETWEEN @Nota_De AND @Nota_Ate
	AND ENFVENCOD IN (SELECT codigoVendedor FROM #Vendedores) 
	AND ENFESTDES IN (SELECT uf FROM #Estados) 
	AND ENFTIPDOC IN (SELECT tipdoc FROM #TiposDoc)
	AND ENFFINEMI IN (SELECT finemi FROM #FinalEmi)
	AND ENFSIT IN (SELECT sit FROM #Situacao)
	AND SNESER IN (SELECT serie FROM #SeriesNFe)
	'
	+
	IIF(@DesRem_Cod <= 0, '', ' AND ENFCODDES = @DesRem_Cod')
	+
	IIF(@DesRem_Nom = '', '', ' AND ENFDESREM LIKE @DesRem_Nom')
	+
	IIF(@DesRem_CnpjCPF = '', '', ' AND ENFCNPJCPF = @DesRem_CnpjCPF')	
	+
	IIF(@chaveAcesso_NFe = '', '', ' AND ENFCHAACE = @chaveAcesso_NFe')	

	-- Executa a Query din�minca(QD)
	SET @ParmDef = N'@empresaTBS080 smallint, @Data_De date, @Data_Ate date, @Nota_De int, @Nota_Ate int, @DesRem_Cod int, @DesRem_Nom varchar(60),
	@DesRem_CnpjCPF varchar(14), @chaveAcesso_NFe varchar(44)'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS080, @Data_De, @Data_Ate, @Nota_De, @Nota_Ate, @DesRem_Cod, @DesRem_Nom, @DesRem_CnpjCPF, @chaveAcesso_NFe

------------------------------------------------------------------------------------------------------------------------------------------------------
	SELECT * FROM #NotasNfe
	ORDER BY ENFDATEMI, SNESER, ENFNUM
------------------------------------------------------------------------------------------------------------------------------------------------------
End