/*
====================================================================================================================================================================================
WREL007 - Clientes atendidos por data e hora no frente de loja
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
06/04/2026 WILLIAM
	- Alteracao do nome da SP, de "usp_RS_ClientesAtendidosDataHoraLoja" para "usp_RS_WREL007_ClientesAtendidosDataHoraLoja", para padronizar com o nome do relatorio;
	- Calculo dos totais geral de cada grupo, data, hora, grupo de vendedor, operador e caixa, retirando a reponsabilidade do RerportServer de calcular, melhorando a performance do relatorio;
	- Utilizacao de CTE em vez de criar tabelas temporarias, para melhorar a legibilidade do codigo;
28/01/2026 WILLIAM
	- Corracao para filtrar as vendas pelos caixas selecionados pelo usuario via parametros do relatorio;
14/02/2025 WILLIAM
	- Inclusao do parametro de entrada @pDesconsideCancelados, para repassar para a SP "usp_Get_DWVendas";
	- Alteracao nos parametros da SP "usp_Get_DWVendas", passando o @pDesconsideCancelados;
13/02/2025 WILLIAM
	- Alteracao nos parametros da SP "usp_Get_DWVendas", retirando o @pcancelado;
11/02/2025 WILLIAM
	- Uso da SP "usp_Get_DWVendas", para obter dados das vendas de loja;
	- Refinamento do codigo, para adaptar aos dados da DWVendas;
30/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Uso da funcao "ufn_Get_Parametro";
06/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Uso da SP "usp_ClientesGrupo" para obter a lista de clientes do grupo BMPT;	
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_RS_WREL007_ClientesAtendidosDataHoraLoja]
CREATE PROC [dbo].[usp_RS_WREL007_ClientesAtendidosDataHoraLoja]
	@pEmpCod smallint,
	@pDataDe datetime,
	@pDataAte datetime,
	@pCaixa varchar(100),
	@pDesconsiderarCancelados char(1) = 'S'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataDe datetime, @dataAte datetime, @Caixas varchar(100), @DesconsiderarCancelados char(1),
			@empresaTBS004 smallint;
			
-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod;
	SET @dataDe = @pDataDe;
	SET @dataAte = ISNULL(@pDataAte, GETDATE());
	SET @Caixas = @pCaixa;
	SET @DesconsiderarCancelados = @pDesconsiderarCancelados;

-- Uso da funcao split, para as clausulas IN()
	IF OBJECT_ID('tempdb.dbo.#CAIXAS') IS NOT NULL
		DROP TABLE #CAIXAS;
    SELECT 
		elemento as caixa 
	INTO #CAIXAS FROM fSplit(@Caixas, ',')

-- Verificar se a tabela e compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem as vendas de loja via SP que retorna dados da DWVendas, gerando a tabela global ##DWVendas
	
	EXEC usp_Get_DWVendas 
		@empcod = @codigoEmpresa, 
		@pdataDe = @dataDe, 
		@pdataAte = @dataAte,
		@pcontabiliza = 'C,L',
		@pDesconsiderarCancelados = @DesconsiderarCancelados;

--SELECT * from ##DWVendas;		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Primeiramente, sera necessario fazer um agrupamento por cupom, pois os dados da DWVendas estao a nivel de itens,
	-- dessa forma, para obter o total por cupom similar ao status = '03', devemos agrupar os dados por cupom somando os valores dos itens de cada cupom

	WITH
	total_por_cupom AS (
	SELECT 
		data,
		hora,
		caixa,
        numeroDocumento,		
		codigoOperador AS operador,
		codigoVendedor AS vendedor,
        sum(valorTotal) AS valor
    FROM ##DWVendas (NOLOCK)

	WHERE 
		caixa in(SELECT caixa FROM #CAIXAS)	-- Somente vendas de loja, pois pode haver dados que registrou loja(@pcontabiliza = 'L'), porem e vendas do delivery via pedido de vendas

	GROUP BY
		codigoEmpresa,
		data,
        hora,		
        caixa,
		numeroDocumento,		
		codigoOperador,
		codigoVendedor
	),--SELECT * FROM total_por_cupom;	
	cupons_por_hora AS (
		SELECT 
		data,
		SUBSTRING(hora, 1, 2) + ':00' + '~' + SUBSTRING(hora, 1, 2) + ':59' AS hora,
		caixa,
		operador,
		count(*) AS clientes,
		sum(valor) AS valor,
		vendedor
	 FROM total_por_cupom

	GROUP BY
		data,
		subString(hora, 1, 2),
		caixa,
		operador,
		vendedor
	),--	select * from cupons_por_hora;
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	notas_delivery AS (
	SELECT 
		data,
		hora,
        numeroDocumento,		
		codigoVendedor AS operador,
        sum(valorTotal) AS valor
    FROM ##DWVendas (NOLOCK)

	WHERE 
        contabiliza = 'L' AND
		caixa = 0 AND
        documentoReferenciado = ''  -- Sem referencia de cupom fiscal, significa que gerou nota sem cupom, via pedido de vendas
	GROUP BY
		codigoEmpresa,
		data,
        hora,		
		numeroDocumento,
		codigoVendedor
	),-- select * from  notas_delivery;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	notas_delivery_por_hora AS (
	SELECT 
		data,
		SUBSTRING(hora, 1, 2) + ':00' + '~' + SUBSTRING(hora, 1, 2) +':59' as hora,
		0 as caixa, 
		operador,
		COUNT(*) as clientes,
		SUM(valor) as valor, 
		'Delivery NF' as grupo
	FROM notas_delivery

	GROUP BY
		data,
		subString(hora, 1, 2),
		operador
	),-- SELECT * FROM notas_delivery_por_hora;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	vendedores AS (
	SELECT 
		VENCOD as codigoVendedor, 
		case GVECOD
			when 2 then 'Delivery NFCupom'
			else 'Corp NFCupom'
		end as grupo, 
		GVECOD as grupoVendedor
	FROM TBS004 (NOLOCK)

	WHERE 
		VENEMPCOD = @empresaTBS004
	),-- select * from vendedores;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento das vendas dos cupons fiscais
	cupons_vendedores AS(
	SELECT  
		data,
		hora,
		caixa,
		operador,
		clientes,
		valor,
		ISNULL(grupo, 'Loja') as grupo
	FROM cupons_por_hora A
		LEFT JOIN vendedores B on A.vendedor = B.codigoVendedor
	), -- select * from cupons_vendedores;
	
	cupons_unificados AS(
		SELECT 
			* 
		FROM cupons_vendedores

		UNION 
		SELECT 
			*
		FROM notas_delivery_por_hora
	)
	
	-- Tabela final: Calcula os totais por segmento: data, hora, grupo de vendedor e caixa;		
	SELECT
		data,
		hora,
		caixa,
		operador,
		clientes,
		valor,
		grupo,

		SUM(clientes) OVER() AS clientes_Geral,
		SUM(valor) OVER() AS total_Geral,
		SUM(clientes) OVER(PARTITION BY data) AS clientes_data,
		SUM(valor) OVER(PARTITION BY data) AS total_data,
		SUM(clientes) OVER(PARTITION BY data, hora) AS clientes_data_hora,
		SUM(valor) OVER(PARTITION BY data, hora) AS total_data_hora,
		SUM(clientes) OVER(PARTITION BY data, hora, grupo) AS clientes_data_hora_grupo,
		SUM(valor) OVER(PARTITION BY data, hora, grupo) AS total_data_hora_grupo,
		SUM(clientes) OVER(PARTITION BY data, hora, grupo, caixa) AS clientes_data_hora_grupo_caixa,
		SUM(valor) OVER(PARTITION BY data, hora, grupo, caixa) AS total_data_hora_grupo_caixa
	FROM cupons_unificados
	ORDER BY
		data,
		hora,
		caixa,
		grupo,
		operador;
/**/		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais
	DROP TABLE ##DWVendas;		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END