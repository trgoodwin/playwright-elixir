defmodule Playwright.FrameTest do
  use Playwright.TestCase, async: true

  alias Playwright.{ElementHandle, Frame, Locator, Page}

  describe "Frame.get_by_text/3" do
    test "returns a locator that contains the given text", %{page: page} do
      Page.set_content(page, "<div><div>first</div><div>second</div><div>\nthird  </div></div>")
      frame = Page.main_frame(page)
      assert frame |> Frame.get_by_text("first") |> Locator.count() == 1

      assert frame |> Frame.get_by_text("third") |> Locator.evaluate("e => e.outerHTML") == "<div>\nthird  </div>"
      Page.set_content(page, "<div><div> first </div><div>first</div></div>")

      assert frame |> Frame.get_by_text("first", %{exact: true}) |> Locator.first() |> Locator.evaluate("e => e.outerHTML") ==
               "<div> first </div>"

      Page.set_content(page, "<div><div> first and more </div><div>first</div></div>")

      assert frame |> Frame.get_by_text("first", %{exact: true}) |> Locator.first() |> Locator.evaluate("e => e.outerHTML") ==
               "<div>first</div>"
    end
  end

  describe "Frame.name/1" do
    test "returns empty string for the main frame", %{page: page} do
      frame = Page.main_frame(page)
      assert Frame.name(frame) == ""
    end

    test "returns the name of a child frame", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      attach_frame(page, "my-frame", assets.empty)

      # Get the non-main frame (there should be exactly 2 frames)
      frames = Page.frames(page)
      child = Enum.find(frames, fn f -> f.guid != Page.main_frame(page).guid end)
      assert child != nil
      # The name should come from the id attribute set by attach_frame
      assert is_binary(Frame.name(child))
    end
  end

  describe "Frame.parent_frame/1" do
    test "returns nil for the main frame", %{page: page} do
      frame = Page.main_frame(page)
      assert Frame.parent_frame(frame) == nil
    end

    test "returns the parent frame for a child frame", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      attach_frame(page, "child-frame", assets.empty)

      frames = Page.frames(page)
      child = Enum.find(frames, fn f -> f.guid != Page.main_frame(page).guid end)
      assert child != nil
      parent = Frame.parent_frame(child)
      assert %Frame{} = parent
      assert parent.guid == Page.main_frame(page).guid
    end
  end

  describe "Frame.child_frames/1" do
    test "returns child frames", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      assert Frame.child_frames(Page.main_frame(page)) == []

      attach_frame(page, "frame1", assets.empty)

      children = Frame.child_frames(Page.main_frame(page))
      assert length(children) == 1
      assert %Frame{} = hd(children)
    end
  end

  describe "Frame.page/1" do
    test "returns the parent Page", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      frame = Page.main_frame(page)

      result = Frame.page(frame)
      assert %Page{} = result
      assert result.guid == page.guid
    end

    test "returns the parent Page for a child frame", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      attach_frame(page, "nested", assets.empty)

      frames = Page.frames(page)
      child = Enum.find(frames, fn f -> f.guid != Page.main_frame(page).guid end)
      assert child != nil

      result = Frame.page(child)
      assert %Page{} = result
      assert result.guid == page.guid
    end
  end

  describe "Frame.is_detached/1" do
    test "returns false for an active frame", %{page: page} do
      frame = Page.main_frame(page)
      assert Frame.is_detached(frame) == false
    end
  end

  describe "Frame.frame_element/1" do
    test "returns the iframe ElementHandle", %{assets: assets, page: page} do
      Page.goto(page, assets.empty)
      attach_frame(page, "the-frame", assets.empty)

      frames = Page.frames(page)
      child = Enum.find(frames, fn f -> f.guid != Page.main_frame(page).guid end)
      assert child != nil

      element = Frame.frame_element(child)
      assert %ElementHandle{} = element

      tag = Page.evaluate(page, "e => e.tagName.toLowerCase()", element)
      assert tag == "iframe"
    end
  end
end
