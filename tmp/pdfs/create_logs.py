from pathlib import Path
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import A4
from pypdf import PdfReader
pdfmetrics.registerFont(TTFont('Song','/System/Library/Fonts/Supplemental/Songti.ttc',subfontIndex=0))
logs=[('三','让渔村调查有更多选择','''最近，我们重新整理了渔村章节，把原先按固定顺序推进的流程改成了六天自由调查。每天有三点行动点，玩家可以自行决定接触谁、调查什么，以及什么时候公开手里的发现。

盐嫂、哑伯和螺螺依然是调查的重要入口。人物问候、阅读资料和区域内移动免费，实际行动则在确认前显示费用、前置条件与后果。对白读完后，玩家可以继续安排当天的事情，不会自动结束回合。

这次调整的重点，是让“找到线索”与“证明线索”有所区别。拿到丈夫手记或船体碎片，只代表获得了调查材料；玩家还需要让不同来源相互印证，例如将手记与船体构件对照，或结合构件和水线进行核验。复制同一份材料不会增加独立证据，认知数值再高，也不能替代调查本身。

时间限制让行动顺序有了意义。家人安置、遗迹调查和公开说明都有各自的窗口。玩家需要在寻找证据、保护人物和传播发现之间分配有限的时间，也可以带着尚未完成的调查离村，接受对应的阶段结果。

人物风险也进一步细化。信任与警戒共同影响合作：有人会因为害怕而暂停帮助，有人可能进入告密预警。实名公开能够扩大影响，却可能暴露提供证词的人；匿名物证和邻里传播则提供了不同的取舍。道歉可以修复部分关系，但不能让已经公开的身份重新变成秘密。

表现方面，我们补充了渔村、遗迹、集市、旧学城和羽之森的背景素材，并继续沿用人物卡、立绘和点击推进对白的操作。无法执行的行动会显示原因，已完成内容也有固定入口可以回看。

渔村现在已经具备调查、核验、传播、风险处理和离村结算的完整流程。接下来还需要通过试玩观察：玩家能否理解这些选择，以及时间压力是否给调查留下了足够的思考空间。'''),
('四','把各地的发现连接起来','''随着渔村流程逐渐稳定，我们把探索扩展到了集市、旧学城和羽之森。目前，六天渔村、四天集市、五天旧学城和五天羽之森已经能够连续游玩，前一地区留下的材料、关系与风险，也会影响下一段旅程。

集市围绕一个问题展开：关于海洋的信息，为什么传不出去？玩家可以从旧文本与查禁清单入手，也可以核对古物货单和扣押记录。调查完成后，还要选择如何让发现抵达读者：自行走访、借助客栈定向递送、公开印刷，或者交给商队外送。

这些方式有不同的时间成本与风险。印好材料并不等于已经有人读到，商队也要实际抵达才产生影响。印刷点遭到搜查，会影响之后的传播能力，但已经送达的消息不会被抹去。我们希望玩家能看清每一步究竟完成了什么。

旧学城进一步把问题引向历史的删改。一张旧港口图与新版记载之间的矛盾，带出版本、交接记录和修订规定的调查。墨先生、二笔和高帽子各有顾虑，也各自提供不同的帮助。玩家可以选择分散保存并讲读、在审议中公开质证，或提交正式异议。取得受理回执，只能证明材料进入了程序，并不代表官方已经接受结论。

羽之森则加入了实际观察与复核。玩家需要核实普通羽人的飞行史，准备有见证的尝试，并在另一天完成复核。一次尝试不能替代整个验证过程；飞行成功也不会自动增加公众对海洋的认知，还需要把相关依据向居民说明。

章节之间的联系已经落到具体行动上。渔村留下的介绍可以帮助集市联络，集市形成的读者渠道能支持学城调查，学城保存的旧史和札记又能为羽之森提供入口。帮助来自玩家实际完成的事情，人物的未决风险也会继续推进。

这一阶段，游戏已经能够让玩家带着前面的选择走进新的地区。后续还需要继续打磨章节交接提示与人物表现，让这些联系在游玩时更容易被感受到。'''),
('五','贯通王城终章，让结局回应整段旅程','''最近，我们完成了王城六回合终章的接入。从渔村出发，经过集市、旧学城和羽之森，玩家现在可以一路进入王城，并走向“海回归”“王国获得解放”“新的王”或“遗忘重临”四类结局。

终章开发中最重要的一次调整，是重新明确前面各地区的作用。海回归需要渔村已经完成的实证核验、羽之森的跨日复核，以及前区真实形成的读者和传播成果。仅在王城完成本地调查，无法补出此前从未建立的公众支持。

不同地区的成果也对应不同的解决方式。旧学城查明的删改责任链，可以支持正式追责；集市建立的传播组织，则能够支撑分散拒绝集中查封。玩家不必把所有人物路线全部完成，但需要为自己选择的方向准备实际依据。

四种结局保留了不同的主动选择。即使满足海回归条件，玩家仍可以选择先建立自由交流的秩序；祭司交出法器，也不会自动让玩家成为新的统治者。只有明确选择接管与独占，才会走向“新的王”。我们希望结局能够回应玩家如何使用手中的力量。

终章还补充了失联与恢复联系的处理。已有读者的地区可以接收后续证据，失联渠道也有寻找替代联络人的机会。但新的联系人不会让原本受影响的人物自动恢复协助，已经发生的风险仍然保留。与此同时，渠道关闭也不会撤销此前真实发生的传播。

为了检查整段流程，项目增加了跨章节的连续路线测试。10月17日的验证报告记录了九条从渔村到王城的代表路线，共通过987项检查；另有164项检查覆盖王城资格、补传、联系恢复和存档。路线包括保护来源后达成海回归、正式追责获得解放、接管组织，以及调查不足时进入遗忘重临。

目前，五个地区与终章已经贯通，但美术和体验仍有完善空间。王城仍使用地图背景与姓名卡占位，部分角色也尚无专属画像。下一阶段的重点，是继续补齐表现，并通过真人试玩检查行动提示、章节节奏和结局条件是否足够清楚。''')]
body=ParagraphStyle('body',fontName='Song',fontSize=11,leading=19,spaceAfter=12,wordWrap='CJK',textColor=HexColor('#302d29'))
title=ParagraphStyle('title',fontName='Song',fontSize=21,leading=29,spaceAfter=21,textColor=HexColor('#463727'))
kicker=ParagraphStyle('kicker',fontName='Song',fontSize=11,leading=18,spaceAfter=9,textColor=HexColor('#8a7153'))
def page(c,d):
 c.setStrokeColor(HexColor('#c8bda9')); c.line(48,43,A4[0]-48,43)
 c.setFont('Song',9); c.setFillColor(HexColor('#857766')); c.drawString(48,28,'被遗忘的海 · 开发日志'); c.drawRightString(A4[0]-48,28,str(d.page))
for number,heading,content in logs:
 path=Path('output/pdf')/f'开发日志{number}_{heading}.pdf'
 doc=SimpleDocTemplate(str(path),pagesize=A4,leftMargin=48,rightMargin=48,topMargin=46,bottomMargin=57,title=f'《被遗忘的海》开发日志（{number}）：{heading}')
 doc.build([Paragraph(f'《被遗忘的海》 · 开发日志（{number}）',kicker),Paragraph(heading,title)]+[Paragraph(p,body) for p in content.split('\n\n')],onFirstPage=page,onLaterPages=page)
 r=PdfReader(path)
 extracted=''.join(p.extract_text() for p in r.pages)
 assert ''.join(content.split()) in ''.join(extracted.split())
 print(path,len(r.pages),'page(s), text verified')
