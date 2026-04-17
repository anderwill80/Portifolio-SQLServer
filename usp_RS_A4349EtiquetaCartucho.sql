/*
====================================================================================================================================================================================
WREL136 - Enderecos Por Rua
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
07/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Inclusão do filtro por empresa de tabela, usando a SP "usp_GetCodigoEmpresaTabela";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_A4349EtiquetaCartucho]
	@empcod smallint,
	@linhaInicial int,
	@colunaInicial int,
	@quantidade int,
	@valor varchar(5),
	@recebido datetime
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @Rua varchar(5), @LinIni int, @ColIni int, @interacao int, @Quanti int, @Val varchar(5), @DatRecebido datetime,
			@etiquetaDe int, @etiquetaAte int;

	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @LinIni = @linhaInicial;
	SET @ColIni = @colunaInicial;
	SET @Val = @valor;
	SET @Quanti = @quantidade;
	SET @DatRecebido = @recebido;

	SET @interacao = 0;
	SET @etiquetaDe = @LinIni * 7 - 7 + @ColIni;
	SET @etiquetaAte = @Quanti - 1 + @etiquetaDe;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	if object_id('tempdb.dbo.#EtiquetasA4349') is not null 	
		drop table #EtiquetasA4349;	

	create table #EtiquetasA4349 (rank int, imprimir char(1), dataAtual date, valor varchar(5))

	while @interacao < @etiquetaAte
	begin	
		begin
	
			insert into #EtiquetasA4349 
	
			select 
			@interacao + 1, 
			case when @interacao + 1 between @etiquetaDe and @etiquetaAte
				then 'S'
				else 'N'
			end ,
			case when @DatRecebido is null then convert(date, getdate()) else convert(date, @DatRecebido) end,
			upper(@Val)
	
		end	
		set @interacao = @interacao + 1
	end
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	select * from #EtiquetasA4349
END