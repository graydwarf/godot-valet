extends Node

func GetId():
	return Uuid.v4()

func SelectOptionButtonValueByText(optionButton : OptionButton, text):
	var count = optionButton.item_count
	for i in range(count):
		if optionButton.get_item_text(i) == text:
			optionButton.select(i)
			return
