/*
====================================================================================================================================================================================
Script do Report Server					Notas fiscais em trânsito
====================================================================================================================================================================================
										Historico de alteracoes
====================================================================================================================================================================================
Data		Por							
- Descricao
**********	*******************
11/12/2024	ANDERSON WILLIAM
- Conversao para Stored procedure;
- Correção na ambiguidade do atributo MARCOD da TBS010 e TBS015;
************************************************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_DadosPoliticaPrecos(
--create proc [dbo].usp_RS_DadosPoliticaPrecos(
	@empcod int,
	@dataDe datetime = null,
	@dataAte datetime = null,
	@produtoDe varchar(60) = '',
	@produtoAte varchar(60) = '',
	@codigoDaMarca int = 0,
	@nomeDaMarca varchar(30) = ''
)
as
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- variaveis internas do reporting services

	DECLARE @empresa SMALLINT, @TDPDATATU_DE DATETIME, @TDPDATATU_ATE DATETIME, @TDPPROCOD_DE VARCHAR(60), @TDPPROCOD_ATE VARCHAR(60), @MARCOD INT, @MARNOM varchar(30),
			@empresaTBS010 SMALLINT, @empresaTBS015 SMALLINT, @empresaTBS031 SMALLINT
	
	SET @empresa = @empcod;
	SET @TDPDATATU_DE  = (select isnull(@dataDe, '01/01/1753'));
	SET @TDPDATATU_ATE = (select isnull(@dataAte, GETDATE()));
	SET @TDPDATATU_ATE = CAST(CONVERT(VARCHAR(10), CAST(@TDPDATATU_ATE AS DATE), 112) + ' 23:59:59' AS DATETIME); -- ACRESCENTA AS HORAS

	SET @TDPPROCOD_DE = @produtoDe;
	SET @TDPPROCOD_ATE = (case when @produtoAte = '' then 'Z' else @produtoAte END);
	SET @MARCOD = @codigoDaMarca;
	SET @MARNOM = @nomeDaMarca;
	
	-- Verificar se a tabela compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS015', @empresaTBS015 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS031', @empresaTBS031 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- cria tabela para receber os dados das empresas	

	select 
		rtrim(MARNOM)+' ('+Ltrim(str(TBS010.MARCOD,4))+')' as 'NomeECodigoDaMarca',
		TDPPROCOD as 'CodigoDoProduto',
		TBS010.PRODES as 'DescricaoDoProduto',
		PROUM1 as 'UnidadeDeMedida1',
		PROUM2 as 'UnidadeDeMedida2',
		TDPCUSBAS as 'CustoDaMercadoria',
		PDPMKPCOR1 as 'MarkupDoCorporativo1',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROCOR='S' then TDPPREPRO1 else TDPPRECOR1 end as 'PrecoDoCorporativo1',
		PDPMKPCOR2 as 'MarkupDoCorporativo2',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROCOR='S' then TDPPREPRO2*PROUM2QTD else TDPPRECOR2*PROUM2QTD end as 'PrecoDoCorporativo2',
		PDPMKPLOJ1 as 'MarkupDaLoja1',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROLOJ='S' then TDPPREPRO1 else TDPPRELOJ1 end as 'PrecoDeLoja1',
		PDPMKPLOJ1 as 'MarkupDaLoja2',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROLOJ='S' then TDPPREPRO2*PROUM2QTD else TDPPRELOJ2*PROUM2QTD end as 'PrecoDeLoja2',
		PDPMKPWE11 as 'Markup1DaWeb1',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROWE1='S' then TDPPREPRO1 else TDPPREWE11 end as 'Preco1DaWeb1',
		PDPMKPWE12 as 'Markup2DaWeb1',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROWE1='S' then TDPPREPRO2*PROUM2QTD else TDPPREWE12*PROUM2QTD end as 'Preco2DaWeb1',
		PDPMKPWE21 as 'Markup1DaWeb2',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROWE2='S' then TDPPREPRO1 else TDPPREWE21 end as 'Preco1DaWeb2',
		PDPMKPWE22 as 'Markup2DaWeb2',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROWE2='S' then TDPPREPRO2*PROUM2QTD else TDPPREWE22*PROUM2QTD end as 'Preco2DaWeb2',		
		PDPMKPREV1 as 'MarkupDaRevenda1',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROREV='S' then TDPPREPRO1 else TDPPREREV1 end as 'PrecoDeRevenda1',
		PDPMKPREV2 as 'MarkupDaRevenda2',
		case when TDPVALPROI>=getdate() and getdate()<=TDPVALPROF and TDPPROREV='S' then TDPPREPRO2*PROUM2QTD else TDPPREREV2*PROUM2QTD end as 'PrecoDeRevenda2',
		TDPDATATU as 'DataDaAtualizacao',
		case when getdate()<=TDPVALPROF and TDPPROLOJ='S' then convert(char(8),TDPVALPROF,3) else '' end as 'PromocaoValidaAte',
		PROSTATUS as 'StatusDoProduto',
		isnull((select ESTQTDATU-ESTQTDRES from TBS032 (nolock) where ESTLOC = 1 and PROCOD = TDPPROCOD),0) as 'SaldoDisponivelEstoque1',
		isnull((select ESTQTDATU-ESTQTDRES from TBS032 (nolock) where ESTLOC = 2 and PROCOD = TDPPROCOD),0) as 'SaldoDisponivelEstoque2'
		
	FROM TBS031 (nolock)
	RIGHT JOIN TBS010  (nolock) on PROEMPCOD = @empresaTBS010 AND PROCOD = TDPPROCOD
	LEFT JOIN TBS015 (nolock) on PDPEMPCOD = @empresaTBS015 AND PDPCOD = TDPPROCOD
	Where
	TDPEMPCOD = @empresaTBS031
	AND TDPDATATU between @TDPDATATU_DE AND @TDPDATATU_ATE
	AND TDPPROCOD between @TDPPROCOD_DE AND @TDPPROCOD_ATE
	AND TBS010.MARCOD = (case when @MARCOD = 0 then TBS010.MARCOD else @MARCOD END)
	AND MARNOM between @MARNOM and (case when @MARNOM = '' then 'Z' else @MARNOM END)

	Order by MARNOM,TBS010.PRODES
 END