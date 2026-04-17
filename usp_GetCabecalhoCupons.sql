/*
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
16/04/2024	ANDERSON WILLIAM			- Atribução dos parâmetros de entrada para as variaveis internas, evita o "parameter sniffing" do SQL SERVER;
										- Alteração do prefixo do nome de "SP_" para "usp_";
										- Uso da SP "usp_GetTabelaEmpresa";									
************************************************************************************************************************************************************************************
*/
alter procedure [dbo].[usp_GetCabecalhoCupons](
	@empresa int,
	@dataEmissaoDe datetime,
	@dataEmissaoAte datetime,
	@cupomDe int,
	@cupomAte int,
	@caixa int, 
	@pular int, 
	@numeroItinerario int,
	@ordenarClassificar varchar(50),
	@opcao int
)
As Begin 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	declare @codigoEmpresa int,	@datEmissaoDe datetime, @datEmissaoAte datetime, @cupDe int, @cupAte int, 
			@cxa int, @pul int, @numItinerario int,@ordClassificar varchar(50), @op int, @ChaNFe varchar(44),

			@empresaTBS002 int, @empresaTBS109 int, @select_movcaixagz varchar(2000),  @from_movcaixagz varchar(2000)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições internas
	SET @codigoEmpresa = @empresa
	SET @datEmissaoDe = @dataEmissaoDe
	SET @datEmissaoAte = @dataEmissaoAte
	SET @cupDe = @cupomDe
	SET @cupAte = case when @cupomAte = 0 then 999999 else @cupomAte end
	SET @cxa = @caixa
	SET @pul = @pular
	SET @numItinerario = @numeroItinerario
	SET @ordClassificar = @ordenarClassificar
	SET @op = @opcao
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva
			
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS109', @empresaTBS109 output;
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Criar a tabela temporaria #Cupons, se não, não consigo excluir a coluna cgc2
	
	If object_id('tempdb.dbo.#Cupons') is not null
		drop table #Cupons

	create table #Cupons (
	ultimoItinerario int,
	-- itinerarioContemDocumento bit,
	extrato int,
	data date, 
	hora varchar(8),
	caixa int,
	cupom int,
	--cgc2 varchar(20),
	cgc varchar(20),
	nfce_chave varchar(44),
	nomeCliente varchar(60),
	qtdItens int,
	valorBruto decimal(10,2), 
	desconto decimal(10,2),
	abatimento decimal(10,2),
	descontoItem decimal(10,2),
	acrescimo decimal(10,2),
	acrescimoItem decimal(10,2),
	liquido decimal(10,2))
	
	-- Pegar as vendas dos cupons, que não esteja cancelado	
	-- Tive que separar o select do from, porque se não, não estava fazendo o select na string completa.
	
	set @select_movcaixagz = 
	'select 
	[dbo].[ufn_GetUltimoItinerarioDocumentoEntregue](' + ltrim(str(@empresaTBS109)) + ', 0, ''C'', cupom, 0, caixa) as ultimoItinerario,
	extrato,data,hora,caixa,cupom,
	case when cgc <> '''' then case when len(cgc) = 14 then cgc else substring(cgc, 2, len(cgc) - 1) end else cgc end collate database_default as cgc, 
	nfce_chave, 
	case when a.cgc <> ''''
	then 
			case when len(a.cgc) = 14 
				then [dbo].[RazaoSocialCliente](' + ltrim(str(@empresaTBS002)) + ', replace(replace(a.cgc,''.'',''''),''-'','''') )
				else [dbo].[RazaoSocialCliente](' + ltrim(str(@empresaTBS002)) + ', replace(replace(replace(substring(a.cgc, 2, len(a.cgc) - 1),''.'',''''),''/'',''''),''-'','''') )
			end 
		else '''' 
	end nomeCliente,	
	count(*) as qtdItens,Sum(valortot) as valorBruto, Sum(desccupom) as desconto,Sum(abatpgto) as abatimento,Sum(descitem) as descontoItem,Sum(acrescupom) as acrescimo,
	Sum(acresitem) as acrescimoItem,Sum(valortot)-Sum(desccupom)-Sum(abatpgto)-Sum(descitem)+Sum(acrescupom)+Sum(acresitem) as liquido '

	If @op = 0 -- Pegar de 30 em 30 cupons	
	begin 	
		set @from_movcaixagz = 
		'from movcaixagz a (nolock) 
		
		where 
		data between ''' + replace(convert(char(10), @datEmissaoDe, 102), '.', '') + ''' and ''' + replace(convert(char(10), @datEmissaoAte, 102), '.', '') + ''' and 
		status = ''01'' and 
		cancelado <> ''S'' and 
		caixa in (case when ' + ltrim(str(@cxa)) + ' = 0 then caixa else ' + ltrim(str(@cxa)) + ' end) and 
		cupom between ' + ltrim(str(@cupDe)) + ' and ' + ltrim(str(@cupAte)) + ' and
		[dbo].[ufn_GetItinerarioContemDocumento](' + ltrim(str(@empresaTBS109)) + ', ' + ltrim(str(@numItinerario)) + ', 0, ''C'', cupom, 0, caixa) = 0
		
		group by 
		extrato,data,hora,caixa,cupom,cgc,nfce_chave  
		
		Order by ' + @ordClassificar + ', min(id) offset ' + ltrim(str(@pul)) + ' rows fetch next 30 rows only' 		
	end 	
	Else 	
	begin 		
		set @from_movcaixagz = 
		'from movcaixagz a (nolock) 
		
		where 
		data between ''' + replace(convert(char(10), @datEmissaoDe, 102), '.', '') + ''' and ''' + replace(convert(char(10), @datEmissaoAte, 102), '.', '') + ''' and 
		status = ''01'' and 
		cancelado <> ''S'' and 
		caixa in (case when ' + ltrim(str(@cxa)) + ' = 0 then caixa else ' + ltrim(str(@cxa)) + ' end) and 
		cupom between ' + ltrim(str(@cupDe)) + ' and ' + ltrim(str(@cupAte)) + ' and
		[dbo].[ufn_GetItinerarioContemDocumento](' + ltrim(str(@empresaTBS109)) + ', ' + ltrim(str(@numItinerario)) + ', 0, ''C'', cupom, 0, caixa) = 0
		
		group by 
		extrato,data,hora,caixa,cupom,cgc,nfce_chave  
		
		Order by ' + @ordClassificar + ', min(id) '	
	end
		
	insert into #Cupons
	exec (@select_movcaixagz + @from_movcaixagz)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
	-- Retorno a tabela 
	
	select 
	ultimoItinerario,
	-- itinerarioContemDocumento,
	extrato,
	data, 
	hora,
	caixa,
	cupom,
	cgc,
	nfce_chave,
	nomeCliente,
	qtdItens,
	valorBruto, 
	desconto,
	abatimento,
	descontoItem,
	acrescimo,
	acrescimoItem,
	liquido
	
	from #Cupons	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
end
GO


